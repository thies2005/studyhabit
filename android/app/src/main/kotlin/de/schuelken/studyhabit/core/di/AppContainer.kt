package de.schuelken.studyhabit.core.di

import android.content.Context
import com.jakewharton.retrofit2.converter.kotlinx.serialization.asConverterFactory
import de.schuelken.studyhabit.core.database.AppDatabase
import de.schuelken.studyhabit.core.network.AuthInterceptor
import de.schuelken.studyhabit.core.network.StudyHabitApi
import de.schuelken.studyhabit.core.network.TokenStorage
import de.schuelken.studyhabit.core.preferences.AppPreferences
import de.schuelken.studyhabit.core.service.AchievementEvaluator
import de.schuelken.studyhabit.core.service.ExportImportService
import de.schuelken.studyhabit.core.service.FolderSyncService
import de.schuelken.studyhabit.core.service.ReminderScheduler
import de.schuelken.studyhabit.core.service.StreakManager
import de.schuelken.studyhabit.core.service.SyncEngine
import kotlinx.serialization.json.Json
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.Interceptor
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import retrofit2.Retrofit
import java.util.concurrent.TimeUnit

class AppContainer(val context: Context) {
    val preferences = AppPreferences(context)
    val tokenStorage = TokenStorage(context)
    val database = AppDatabase.getInstance(context)

    private val json = Json {
        ignoreUnknownKeys = true
        coerceInputValues = true
        isLenient = true
        encodeDefaults = true
        explicitNulls = false
    }

    private val dynamicUrlInterceptor = Interceptor { chain ->
        var request = chain.request()
        val rawUrl = preferences.serverUrl.value.trim().removeSuffix("/")
        if (rawUrl.isEmpty()) {
            throw java.io.IOException("Server URL is not configured. Please set your Server URL in Sync Settings.")
        }
        val baseWithApi = if (rawUrl.endsWith("/api/v1")) "$rawUrl/" else "$rawUrl/api/v1/"
        val targetBase = baseWithApi.toHttpUrlOrNull()
            ?: throw java.io.IOException("Invalid Server URL: $rawUrl")
        val relativePath = request.url.encodedPath.removePrefix("/api/v1/")
        val newUrl = targetBase.newBuilder()
            .addEncodedPathSegments(relativePath.trimStart('/'))
            .encodedQuery(request.url.encodedQuery)
            .build()
        request = request.newBuilder().url(newUrl).build()
        chain.proceed(request)
    }

    private val okHttpClient = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(20, TimeUnit.SECONDS)
        .writeTimeout(20, TimeUnit.SECONDS)
        .addInterceptor(dynamicUrlInterceptor)
        .addInterceptor(AuthInterceptor(tokenStorage))
        .build()

    val api: StudyHabitApi = Retrofit.Builder()
        .baseUrl("http://localhost/api/v1/")
        .client(okHttpClient)
        .addConverterFactory(json.asConverterFactory("application/json".toMediaType()))
        .build()
        .create(StudyHabitApi::class.java)

    val streakManager = StreakManager(database.userStatsDao(), preferences)
    val achievementEvaluator = AchievementEvaluator(database)
    val syncEngine = SyncEngine(api, database, preferences, tokenStorage)
    val exportImportService = ExportImportService(context, database, preferences)
    val folderSyncService: FolderSyncService by lazy {
        FolderSyncService(context, database, preferences, exportImportService)
    }
    val reminderScheduler = ReminderScheduler(context, preferences)

    fun triggerDataChangedSync() {
        if (!tokenStorage.getToken().isNullOrBlank() && preferences.serverUrl.value.isNotBlank()) {
            syncEngine.scheduleDebouncedSync()
        }
        if (preferences.folderSyncEnabled.value && !preferences.folderSyncUri.value.isNullOrBlank()) {
            folderSyncService.scheduleDebouncedSync()
        }
    }
}

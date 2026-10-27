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

import okhttp3.Authenticator
import okhttp3.Request
import okhttp3.Response
import okhttp3.Route
import okhttp3.RequestBody.Companion.toRequestBody
import de.schuelken.studyhabit.core.network.RefreshRequest
import de.schuelken.studyhabit.core.network.RefreshResponse
import de.schuelken.studyhabit.core.network.ApiResponse

class TokenAuthenticator(
    private val tokenStorage: TokenStorage,
    private val preferences: AppPreferences,
    private val json: Json,
) : Authenticator {
    @Synchronized
    override fun authenticate(route: Route?, response: Response): Request? {
        val path = response.request.url.encodedPath
        if (path.endsWith("auth/login") || path.endsWith("auth/register") || path.endsWith("auth/refresh")) {
            return null
        }

        var priorResponse = response.priorResponse
        var priorCount = 0
        while (priorResponse != null) {
            priorCount++
            if (priorCount >= 2) return null
            priorResponse = priorResponse.priorResponse
        }

        val requestAuth = response.request.header("Authorization")
        val currentToken = tokenStorage.getToken()
        if (!currentToken.isNullOrBlank() && requestAuth != null && requestAuth != "Bearer $currentToken") {
            return response.request.newBuilder()
                .header("Authorization", "Bearer $currentToken")
                .build()
        }

        val refreshToken = tokenStorage.getRefreshToken() ?: return null

        val rawUrl = preferences.serverUrl.value.trim().removeSuffix("/")
        if (rawUrl.isBlank()) return null
        val baseWithApi = if (rawUrl.endsWith("/api/v1")) "$rawUrl/" else "$rawUrl/api/v1/"
        val refreshUrl = (baseWithApi.toHttpUrlOrNull() ?: return null).newBuilder()
            .addPathSegment("auth")
            .addPathSegment("refresh")
            .build()

        val refreshPayload = json.encodeToString(
            RefreshRequest.serializer(),
            RefreshRequest(refreshToken)
        )
        val refreshBody = refreshPayload.toRequestBody("application/json".toMediaType())
        val refreshReq = Request.Builder()
            .url(refreshUrl)
            .post(refreshBody)
            .build()

        val directClient = OkHttpClient.Builder()
            .connectTimeout(15, TimeUnit.SECONDS)
            .readTimeout(20, TimeUnit.SECONDS)
            .build()

        return try {
            directClient.newCall(refreshReq).execute().use { refreshRes ->
                if (refreshRes.isSuccessful) {
                    val bodyString = refreshRes.body?.string() ?: return null
                    val refreshResp = json.decodeFromString(
                        ApiResponse.serializer(RefreshResponse.serializer()),
                        bodyString
                    )
                    val newAccessToken = refreshResp.data.accessToken
                    val newRefreshToken = refreshResp.data.refreshToken
                    tokenStorage.saveToken(newAccessToken)
                    tokenStorage.saveRefreshToken(newRefreshToken)

                    response.request.newBuilder()
                        .header("Authorization", "Bearer $newAccessToken")
                        .build()
                } else {
                    tokenStorage.clear()
                    null
                }
            }
        } catch (e: Exception) {
            null
        }
    }
}

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
        if (rawUrl.isBlank()) {
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
        .authenticator(TokenAuthenticator(tokenStorage, preferences, json))
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

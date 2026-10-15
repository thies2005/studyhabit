package de.schuelken.studyhabit.core.network

import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.POST
import retrofit2.http.Query

interface StudyHabitApi {
    @POST("auth/login")
    suspend fun login(@Body request: LoginRequest): ApiResponse<AuthData>

    @POST("auth/register")
    suspend fun register(@Body request: RegisterRequest): ApiResponse<AuthData>

    @GET("auth/me")
    suspend fun getMe(): ApiResponse<UserInfo>

    @POST("sync/full")
    suspend fun fullSync(
        @Query("since") since: String,
        @Body payload: SyncPushPayload
    ): SyncResponse

    @POST("sync/erase")
    suspend fun eraseData(): SuccessResponse

    @GET("stats/xp-history")
    suspend fun getXpHistory(): ApiResponse<List<XpHistoryItem>>
}

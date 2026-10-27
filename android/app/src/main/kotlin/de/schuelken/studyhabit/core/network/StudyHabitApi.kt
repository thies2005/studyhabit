package de.schuelken.studyhabit.core.network

import kotlinx.serialization.Serializable
import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.POST
import retrofit2.http.Query

@Serializable
data class RefreshRequest(val refreshToken: String)

@Serializable
data class RefreshResponse(val accessToken: String, val refreshToken: String)

interface StudyHabitApi {
    @POST("auth/login")
    suspend fun login(@Body request: LoginRequest): ApiResponse<AuthData>

    @POST("auth/register")
    suspend fun register(@Body request: RegisterRequest): ApiResponse<AuthData>

    @POST("auth/refresh")
    suspend fun refresh(@Body request: RefreshRequest): ApiResponse<RefreshResponse>

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

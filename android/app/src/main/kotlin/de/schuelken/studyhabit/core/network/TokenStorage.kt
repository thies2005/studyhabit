package de.schuelken.studyhabit.core.network

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

class TokenStorage(context: Context) {
    private val prefs: SharedPreferences = createEncryptedPrefsWithRecovery(context.applicationContext)

    private fun createEncryptedPrefsWithRecovery(appContext: Context): SharedPreferences {
        return try {
            createPrefs(appContext)
        } catch (e: Exception) {
            Log.w("TokenStorage", "EncryptedSharedPreferences corrupted or key invalidated; resetting", e)
            runCatching { appContext.deleteSharedPreferences("secure_tokens") }
            createPrefs(appContext)
        }
    }

    private fun createPrefs(appContext: Context): SharedPreferences {
        val masterKey = MasterKey.Builder(appContext)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        return EncryptedSharedPreferences.create(
            appContext,
            "secure_tokens",
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }

    fun getToken(): String? = prefs.getString("auth_token", null)

    fun saveToken(token: String) {
        prefs.edit().putString("auth_token", token).apply()
    }

    fun getUserId(): String? = prefs.getString("user_id", null)

    fun getUserEmail(): String? = prefs.getString("user_email", null)

    fun saveUser(id: String, email: String) {
        prefs.edit()
            .putString("user_id", id)
            .putString("user_email", email)
            .apply()
    }

    fun clear() {
        prefs.edit().clear().apply()
    }
}

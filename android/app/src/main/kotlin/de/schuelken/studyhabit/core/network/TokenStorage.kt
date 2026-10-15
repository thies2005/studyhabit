package de.schuelken.studyhabit.core.network

import android.content.Context
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

class TokenStorage(context: Context) {
    private val masterKey = MasterKey.Builder(context)
        .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
        .build()

    private val prefs = EncryptedSharedPreferences.create(
        context,
        "secure_tokens",
        masterKey,
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
    )

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

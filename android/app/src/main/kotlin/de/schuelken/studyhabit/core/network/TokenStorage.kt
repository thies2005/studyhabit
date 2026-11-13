package de.schuelken.studyhabit.core.network

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import java.util.concurrent.ConcurrentHashMap

class TokenStorage(context: Context) {
    private val prefs: SharedPreferences = createEncryptedPrefsWithRecovery(context.applicationContext)

    private fun createEncryptedPrefsWithRecovery(appContext: Context): SharedPreferences {
        return try {
            createPrefs(appContext)
        } catch (firstError: Exception) {
            Log.w("TokenStorage", "EncryptedSharedPreferences corrupted or key invalidated; resetting", firstError)
            runCatching { appContext.deleteSharedPreferences("secure_tokens") }
            try {
                createPrefs(appContext)
            } catch (secondError: Exception) {
                Log.e("TokenStorage", "EncryptedSharedPreferences unavailable after reset; using volatile in-memory storage", secondError)
                InMemorySharedPreferences()
            }
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

    companion object {
        const val KEY_AUTH_TOKEN = "auth_token"
        const val KEY_REFRESH_TOKEN = "refresh_token"
        const val KEY_USER_ID = "user_id"
        const val KEY_USER_EMAIL = "user_email"
    }

    fun getToken(): String? = prefs.getString(KEY_AUTH_TOKEN, null)

    fun saveToken(token: String) {
        prefs.edit().putString(KEY_AUTH_TOKEN, token).commit()
    }

    fun getRefreshToken(): String? = prefs.getString(KEY_REFRESH_TOKEN, null)

    fun saveRefreshToken(token: String) {
        prefs.edit().putString(KEY_REFRESH_TOKEN, token).commit()
    }

    fun getUserId(): String? = prefs.getString(KEY_USER_ID, null)

    fun getUserEmail(): String? = prefs.getString(KEY_USER_EMAIL, null)

    fun saveUser(id: String, email: String) {
        prefs.edit()
            .putString(KEY_USER_ID, id)
            .putString(KEY_USER_EMAIL, email)
            .commit()
    }

    fun clear() {
        prefs.edit()
            .remove(KEY_AUTH_TOKEN)
            .remove(KEY_REFRESH_TOKEN)
            .remove(KEY_USER_ID)
            .remove(KEY_USER_EMAIL)
            .clear()
            .commit()
    }
}

/**
 * Fallback volatile storage used only if Android Keystore fails twice on startup,
 * avoiding both startup crashes and plaintext token persistence on disk.
 */
private class InMemorySharedPreferences : SharedPreferences {
    private val map = ConcurrentHashMap<String, Any?>()

    override fun getAll(): MutableMap<String, *> = HashMap(map)
    override fun getString(key: String?, defValue: String?): String? =
        (map[key] as? String) ?: defValue
    override fun getStringSet(key: String?, defValues: MutableSet<String>?): MutableSet<String>? =
        @Suppress("UNCHECKED_CAST") ((map[key] as? Set<String>)?.toMutableSet() ?: defValues)
    override fun getInt(key: String?, defValue: Int): Int = (map[key] as? Int) ?: defValue
    override fun getLong(key: String?, defValue: Long): Long = (map[key] as? Long) ?: defValue
    override fun getFloat(key: String?, defValue: Float): Float = (map[key] as? Float) ?: defValue
    override fun getBoolean(key: String?, defValue: Boolean): Boolean = (map[key] as? Boolean) ?: defValue
    override fun contains(key: String?): Boolean = key != null && map.containsKey(key)
    override fun registerOnSharedPreferenceChangeListener(listener: SharedPreferences.OnSharedPreferenceChangeListener?) {}
    override fun unregisterOnSharedPreferenceChangeListener(listener: SharedPreferences.OnSharedPreferenceChangeListener?) {}

    override fun edit(): SharedPreferences.Editor = object : SharedPreferences.Editor {
        private val pending = LinkedHashMap<String, Any?>()
        private var clearFirst = false

        override fun putString(key: String?, value: String?): SharedPreferences.Editor = apply {
            if (key != null) pending[key] = value
        }
        override fun putStringSet(key: String?, values: MutableSet<String>?): SharedPreferences.Editor = apply {
            if (key != null) pending[key] = values?.toSet()
        }
        override fun putInt(key: String?, value: Int): SharedPreferences.Editor = apply {
            if (key != null) pending[key] = value
        }
        override fun putLong(key: String?, value: Long): SharedPreferences.Editor = apply {
            if (key != null) pending[key] = value
        }
        override fun putFloat(key: String?, value: Float): SharedPreferences.Editor = apply {
            if (key != null) pending[key] = value
        }
        override fun putBoolean(key: String?, value: Boolean): SharedPreferences.Editor = apply {
            if (key != null) pending[key] = value
        }
        override fun remove(key: String?): SharedPreferences.Editor = apply {
            if (key != null) pending[key] = null
        }
        override fun clear(): SharedPreferences.Editor = apply {
            clearFirst = true
            pending.clear()
        }
        override fun commit(): Boolean {
            synchronized(map) {
                if (clearFirst) map.clear()
                for ((k, v) in pending) {
                    if (v == null) map.remove(k) else map[k] = v
                }
            }
            return true
        }
        override fun apply() {
            commit()
        }
    }
}

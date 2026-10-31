package de.schuelken.studyhabit.core.service

import java.net.URI

object SourceValidation {
    fun isWebUrl(value: String): Boolean = runCatching {
        val uri = URI(value.trim())
        uri.scheme?.lowercase() in setOf("https", "http") &&
            !uri.host.isNullOrBlank() && uri.rawUserInfo == null &&
            (uri.port == -1 || uri.port in 1..65535)
    }.getOrDefault(false)
}

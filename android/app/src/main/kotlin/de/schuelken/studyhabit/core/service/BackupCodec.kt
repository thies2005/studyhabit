package de.schuelken.studyhabit.core.service

import kotlinx.serialization.json.Json

object BackupCodec {
    val json = Json {
        ignoreUnknownKeys = true
        prettyPrint = true
        encodeDefaults = true
    }

    fun decode(text: String): ExportDocument {
        val document = json.decodeFromString<ExportDocument>(text)
        require(document.exportVersion in 1..2) {
            "Unsupported backup version ${document.exportVersion}. Use a version 1 or 2 backup."
        }
        return document
    }
}

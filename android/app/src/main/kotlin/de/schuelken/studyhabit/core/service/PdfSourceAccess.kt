package de.schuelken.studyhabit.core.service

import android.content.Context
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.os.ParcelFileDescriptor
import java.io.File

object PdfSourceAccess {
    fun open(context: Context, value: String): ParcelFileDescriptor {
        require(value.isNotBlank()) { "Choose a PDF document first." }
        val uri = Uri.parse(value.trim())
        if (uri.scheme == "content") {
            return context.contentResolver.openFileDescriptor(uri, "r")
                ?: error("Could not open this PDF. Choose the document again.")
        }
        require(uri.scheme == null || uri.scheme == "file") { "Choose a local PDF document." }
        val file = File(if (uri.scheme == "file") uri.path.orEmpty() else value.trim()).canonicalFile
        val dataDir = File(context.applicationInfo.dataDir).canonicalFile
        require(file != dataDir && !file.path.startsWith(dataDir.path + File.separator)) {
            "Access to internal app files is prohibited."
        }
        require(file.isFile && file.canRead()) { "PDF file is unavailable. Choose the document again." }
        return ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
    }

    /** Called on IO before save/relink; PdfRenderer also checks the document format. */
    fun validate(context: Context, value: String) {
        open(context, value).use { descriptor ->
            PdfRenderer(descriptor).use { renderer ->
                require(renderer.pageCount > 0) { "This PDF has no pages." }
            }
        }
    }
}

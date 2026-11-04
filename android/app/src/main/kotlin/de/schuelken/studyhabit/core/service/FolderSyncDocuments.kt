package de.schuelken.studyhabit.core.service

import android.content.ContentResolver
import android.net.Uri
import android.provider.DocumentsContract
import java.io.FileNotFoundException
import java.io.IOException

internal class FolderSyncDocuments(private val resolver: ContentResolver, private val tree: Uri) {
    private val rootId = DocumentsContract.getTreeDocumentId(tree)
    private val root = DocumentsContract.buildDocumentUriUsingTree(tree, rootId)

    data class Entry(val name: String, val uri: Uri)

    fun requireWritableFolder() {
        val columns = arrayOf(
            DocumentsContract.Document.COLUMN_MIME_TYPE,
            DocumentsContract.Document.COLUMN_FLAGS,
        )
        val writable = resolver.query(root, columns, null, null, null)?.use { cursor ->
            cursor.moveToFirst() &&
                cursor.getString(0) == DocumentsContract.Document.MIME_TYPE_DIR &&
                (cursor.getInt(1) and DocumentsContract.Document.FLAG_DIR_SUPPORTS_CREATE) != 0
        } ?: false
        if (!writable) throw IOException("This provider does not allow creating files in the selected folder")
    }

    fun list(): List<Entry> {
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, rootId)
        val columns = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
        )
        return resolver.query(children, columns, null, null, null)?.use { cursor ->
            if (cursor.extras.getBoolean(DocumentsContract.EXTRA_LOADING) ||
                !cursor.extras.getString(DocumentsContract.EXTRA_ERROR).isNullOrBlank()
            ) {
                throw IOException("Folder contents are still loading or unavailable")
            }
            buildList {
                while (cursor.moveToNext()) {
                    val id = cursor.getString(0) ?: throw IOException("Folder listing is incomplete")
                    val name = cursor.getString(1) ?: throw IOException("Folder listing is incomplete")
                    if (cursor.getString(2) != DocumentsContract.Document.MIME_TYPE_DIR) {
                        add(Entry(name, DocumentsContract.buildDocumentUriUsingTree(tree, id)))
                    }
                }
            }
        } ?: throw IOException("Could not list the selected folder")
    }

    fun read(uri: Uri): String = resolver.openInputStream(uri)?.use {
        it.bufferedReader(Charsets.UTF_8).readText()
    } ?: throw FileNotFoundException("Could not open sync data for reading")

    fun publish(name: String, contents: String) {
        val uri = DocumentsContract.createDocument(resolver, root, "application/json", name)
            ?: throw IOException("Could not create a sync snapshot in the selected folder")
        // New, unique document: no seeking/truncation and no risk to an existing publication.
        resolver.openOutputStream(uri, "w")?.use { it.write(contents.toByteArray(Charsets.UTF_8)) }
            ?: throw IOException("Could not open the new sync snapshot for writing")
        if (read(uri) != contents) throw IOException("The file provider has not verified the new snapshot")
        val actualName = resolver.query(uri, arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME), null, null, null)
            ?.use { if (it.moveToFirst()) it.getString(0) else null }
        if (actualName != name) throw IOException("The file provider changed the sync snapshot name")
    }
}

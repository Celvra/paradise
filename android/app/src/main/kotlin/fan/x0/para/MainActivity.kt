package fan.x0.para

import android.content.ContentValues
import android.os.Build
import android.provider.MediaStore
import fan.x0.para.workspace.WorkspacePlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.IOException

class MainActivity : FlutterActivity() {
    /// Registered here rather than in an application class because the plugin
    /// needs an activity for FLAG_KEEP_SCREEN_ON and nothing else does.
    // Activity fields are initialized before Android attaches the base context.
    // Creating the plugin there makes applicationContext null on cold launch.
    private var workspacePlugin: WorkspacePlugin? = null
    private var backupChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val plugin = WorkspacePlugin(applicationContext)
        workspacePlugin = plugin
        plugin.configure(flutterEngine.dartExecutor.binaryMessenger)

        // Auto backup lives in MediaStore.Downloads because it is the one
        // place a file outlives the app without any storage permission. The
        // Dart side falls back to a private directory when this channel
        // errors (old api levels, revoked collections).
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "paradise/backup")
        backupChannel = ch
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "write" -> backupWrite((call.arguments as? String ?: "").toByteArray(), BACKUP_NAME, "application/json", result)
                "read" -> backupRead(result)
                "exists" -> backupExists(BACKUP_NAME, result)
                // the full zip backup rides the same channel: one directory,
                // one overwrite policy, two logical files
                "writeFull" -> backupWrite(call.arguments as? ByteArray ?: ByteArray(0), FULL_BACKUP_NAME, "application/zip", result)
                "readFull" -> backupReadBytes(FULL_BACKUP_NAME, result)
                "existsFull" -> backupExists(FULL_BACKUP_NAME, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun backupWrite(content: ByteArray, name: String, mime: String, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 29) {
            result.error("api", "MediaStore.Downloads needs api 29+", null)
            return
        }
        // one logical backup: drop every older copy, including the "(1)"
        // variants some vendors mint when an insert lands before the delete of
        // the previous row becomes visible
        for (uri in queryBackupUris(name)) {
            contentResolver.delete(uri, null, null)
        }
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, name)
            put(MediaStore.Downloads.MIME_TYPE, mime)
            put(MediaStore.Downloads.RELATIVE_PATH, "Download/Paradise")
        }
        val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
        if (uri == null) {
            result.error("io", "insert failed", null)
            return
        }
        try {
            contentResolver.openOutputStream(uri, "wt")?.use { it.write(content) }
                ?: throw IOException("no stream")
            result.success(System.currentTimeMillis())
        } catch (e: Exception) {
            contentResolver.delete(uri, null, null)
            result.error("io", e.message, null)
        }
    }

    private fun backupRead(result: MethodChannel.Result) {
        val raw = backupReadBytes(BACKUP_NAME)
        result.success(raw?.let { String(it) })
    }

    /// Newest first, and every name variant counts: after a reinstall the
    /// row the old install left may sit under "paradise_autobackup (1).json"
    /// on some vendors, and the exact-name query would miss it.
    private fun backupReadBytes(name: String): ByteArray? {
        if (Build.VERSION.SDK_INT < 29) {
            return null
        }
        for (uri in queryBackupUris(name)) {
            try {
                val raw = contentResolver.openInputStream(uri)?.use { it.readBytes() }
                if (raw != null) {
                    return raw
                }
            } catch (e: SecurityException) {
                // a row this install may not open (left by the uninstalled
                // previous one): try the next candidate
            } catch (e: Exception) {
                // unreadable row: same, try the next one
            }
        }
        return null
    }

    private fun backupReadBytes(name: String, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 29) {
            result.error("api", "MediaStore.Downloads needs api 29+", null)
            return
        }
        result.success(backupReadBytes(name))
    }

    /// Whether any backup file is visible at all, readable or not. The Dart
    /// side uses it to offer a manual pick when a reinstall can see the file
    /// but Android will not hand its bytes over without the user tapping it.
    private fun backupExists(name: String, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 29) {
            result.error("api", "MediaStore.Downloads needs api 29+", null)
            return
        }
        result.success(queryBackupUris(name).isNotEmpty())
    }

    /// Newest backup rows of this app in its Downloads folder, exact name and
    /// "name (n)" variants alike, so nothing the previous install wrote is
    /// ever invisible to the next one.
    private fun queryBackupUris(name: String): List<android.net.Uri> {
        val cols = arrayOf(MediaStore.Downloads._ID)
        val sel = "${MediaStore.Downloads.DISPLAY_NAME} LIKE ? AND ${MediaStore.Downloads.RELATIVE_PATH} = ?"
        val args = arrayOf("$name%", "Download/Paradise/")
        val sort = "${MediaStore.Downloads.DATE_ADDED} DESC"
        val out = mutableListOf<android.net.Uri>()
        contentResolver.query(MediaStore.Downloads.EXTERNAL_CONTENT_URI, cols, sel, args, sort)?.use { c ->
            while (c.moveToNext()) {
                out.add(
                    android.net.Uri.withAppendedPath(
                        MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                        c.getLong(0).toString(),
                    ),
                )
            }
        }
        return out
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        workspacePlugin?.attachActivity(this)
    }

    override fun onDestroy() {
        workspacePlugin?.detachActivity(this)
        workspacePlugin = null
        backupChannel = null
        super.onDestroy()
    }

    companion object {
        const val BACKUP_NAME = "paradise_autobackup.json"
        const val FULL_BACKUP_NAME = "paradise_full.zip"
    }
}

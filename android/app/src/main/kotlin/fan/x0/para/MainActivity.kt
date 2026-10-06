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
                "write" -> backupWrite(call.arguments as? String ?: "", result)
                "read" -> backupRead(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun backupWrite(content: String, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 29) {
            result.error("api", "MediaStore.Downloads needs api 29+", null)
            return
        }
        // one logical backup: drop older copies with the same name first
        val keep = queryBackupUri()
        if (keep != null) contentResolver.delete(keep, null, null)
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, BACKUP_NAME)
            put(MediaStore.Downloads.MIME_TYPE, "application/json")
            put(MediaStore.Downloads.RELATIVE_PATH, "Download/Paradise")
        }
        val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
        if (uri == null) {
            result.error("io", "insert failed", null)
            return
        }
        try {
            contentResolver.openOutputStream(uri, "wt")?.use { it.write(content.toByteArray()) }
                ?: throw IOException("no stream")
            result.success(System.currentTimeMillis())
        } catch (e: Exception) {
            contentResolver.delete(uri, null, null)
            result.error("io", e.message, null)
        }
    }

    private fun backupRead(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 29) {
            result.error("api", "MediaStore.Downloads needs api 29+", null)
            return
        }
        val uri = queryBackupUri()
        if (uri == null) {
            result.success(null)
            return
        }
        try {
            val raw = contentResolver.openInputStream(uri)?.use { it.readBytes() }
            result.success(raw?.let { String(it) })
        } catch (e: Exception) {
            result.error("io", e.message, null)
        }
    }

    /// Newest file with the backup name, so a restore after reinstall reads
    /// the copy this install actually wrote last.
    private fun queryBackupUri(): android.net.Uri? {
        val cols = arrayOf(MediaStore.Downloads._ID)
        val sel = "${MediaStore.Downloads.DISPLAY_NAME} = ?"
        val args = arrayOf(BACKUP_NAME)
        val sort = "${MediaStore.Downloads.DATE_ADDED} DESC"
        contentResolver.query(MediaStore.Downloads.EXTERNAL_CONTENT_URI, cols, sel, args, sort)?.use { c ->
            if (c.moveToFirst()) {
                return android.net.Uri.withAppendedPath(
                    MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                    c.getLong(0).toString(),
                )
            }
        }
        return null
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
    }
}

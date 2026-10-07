package fan.x0.para

import android.content.ContentValues
import android.os.Build
import android.provider.MediaStore
import fan.x0.para.workspace.WorkspacePlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

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
                "write" -> backupWrite((call.arguments as? ByteArray) ?: ByteArray(0), result)
                "read" -> backupRead(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun backupWrite(content: ByteArray, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 29) {
            result.error("api", "MediaStore.Downloads needs api 29+", null)
            return
        }
        // A new file per write: the change mode fires after every editing burst,
        // and erasing the one name each time would throw away the copy taken
        // before a bad edit. Older copies are pruned so Downloads cannot grow
        // without bound.
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, backupName())
            put(MediaStore.Downloads.MIME_TYPE, "application/zip")
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
            pruneBackups()
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
        val uri = queryNewestBackup()
        if (uri == null) {
            result.success(null)
            return
        }
        try {
            val raw = contentResolver.openInputStream(uri)?.use { it.readBytes() }
            result.success(raw)
        } catch (e: Exception) {
            result.error("io", e.message, null)
        }
    }

    /// Newest archive this install wrote, so a restore after reinstall reads the
    /// freshest copy.
    private fun queryNewestBackup(): android.net.Uri? {
        val cols = arrayOf(MediaStore.Downloads._ID)
        val sel = "${MediaStore.Downloads.DISPLAY_NAME} LIKE ?"
        val args = arrayOf("$BACKUP_PREFIX%")
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

    /// Keeps the newest BACKUP_KEEP archives and drops the rest. Best effort: a
    /// delete that fails leaves the file behind, which is better than failing
    /// the write that just succeeded because a stale row could not be removed.
    private fun pruneBackups() {
        val cols = arrayOf(MediaStore.Downloads._ID)
        val sel = "${MediaStore.Downloads.DISPLAY_NAME} LIKE ?"
        val args = arrayOf("$BACKUP_PREFIX%")
        val sort = "${MediaStore.Downloads.DATE_ADDED} DESC"
        contentResolver.query(MediaStore.Downloads.EXTERNAL_CONTENT_URI, cols, sel, args, sort)?.use { c ->
            var i = 0
            while (c.moveToNext()) {
                i++
                if (i <= BACKUP_KEEP) continue
                val uri = android.net.Uri.withAppendedPath(
                    MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                    c.getLong(0).toString(),
                )
                try {
                    contentResolver.delete(uri, null, null)
                } catch (_: Exception) {
                    // ignored on purpose, see the method comment
                }
            }
        }
    }

    /// A sortable name: the prefix, a timestamp and the extension. String order
    /// on this name matches time order, which is what queryNewestBackup and
    /// pruneBackups both lean on.
    private fun backupName(): String {
        val f = SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US)
        return "$BACKUP_PREFIX${f.format(Date())}.zip"
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
        const val BACKUP_PREFIX = "paradise_autobackup-"
        const val BACKUP_KEEP = 20
    }
}

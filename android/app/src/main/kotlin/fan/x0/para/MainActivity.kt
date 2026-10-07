package fan.x0.para

import android.content.ContentValues
import android.os.Build
import android.provider.MediaStore
import fan.x0.para.workspace.WorkspacePlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.util.UUID

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
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, "paradise_autobackup-stage-${UUID.randomUUID()}.zip")
            put(MediaStore.Downloads.MIME_TYPE, "application/zip")
            put(MediaStore.Downloads.RELATIVE_PATH, BACKUP_PATH)
            put(MediaStore.Downloads.IS_PENDING, 1)
        }
        var staged: android.net.Uri? = null
        var previous: android.net.Uri? = null
        var previousMoved = false
        var published = false
        try {
            staged = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IOException("insert failed")
            contentResolver.openOutputStream(staged, "w")?.use {
                it.write(content)
                it.flush()
            } ?: throw IOException("no stream")

            // MediaStore cannot atomically replace an existing row. Move the old
            // name aside (without deleting its bytes), then publish the fully
            // written pending row under the fixed name. A crash between updates
            // may leave a previous-* row; backupRead can still recover it.
            previous = backupRows().firstOrNull { it.name == BACKUP_NAME && it.path == BACKUP_PATH }?.uri
            if (previous != null) {
                val previousName = "paradise_autobackup-previous-${UUID.randomUUID()}.zip"
                rename(previous, previousName)
                previousMoved = true
            }
            val publish = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, BACKUP_NAME)
                put(MediaStore.Downloads.IS_PENDING, 0)
            }
            if (contentResolver.update(staged, publish, null, null) != 1) throw IOException("publish failed")
            published = true
            if (displayName(staged) != BACKUP_NAME) throw IOException("backup name was changed by MediaStore")

            // Only remove files in our Paradise folder, after publication was
            // confirmed. Do not delete the older fixed JSON or anything in a
            // different Downloads location.
            try {
                for (old in backupRows()) {
                    if (old.path != BACKUP_PATH || old.uri == staged) continue
                    if (old.name.matches(LEGACY_ZIP) || old.name.matches(PREVIOUS_ZIP)) {
                        try {
                            contentResolver.delete(old.uri, null, null)
                        } catch (_: Exception) {
                            // An undeletable old backup is safer than a failed write.
                        }
                    }
                }
            } catch (_: Exception) {
                // Publication succeeded, even if listing old rows failed.
            }
            result.success(System.currentTimeMillis())
        } catch (e: Exception) {
            if (!published && previousMoved && previous != null) {
                try {
                    rename(previous, BACKUP_NAME)
                } catch (_: Exception) {
                    // The previous-* row remains readable if rollback fails.
                }
            }
            if (!published && staged != null) {
                try {
                    contentResolver.delete(staged, null, null)
                } catch (_: Exception) {}
            }
            result.error("io", e.message, null)
        }
    }

    private fun rename(uri: android.net.Uri, name: String) {
        val values = ContentValues().apply { put(MediaStore.Downloads.DISPLAY_NAME, name) }
        if (contentResolver.update(uri, values, null, null) != 1 || displayName(uri) != name) {
            throw IOException("could not rename backup to $name")
        }
    }

    private fun displayName(uri: android.net.Uri): String? {
        contentResolver.query(uri, arrayOf(MediaStore.Downloads.DISPLAY_NAME), null, null, null)?.use { c ->
            if (c.moveToFirst()) return c.getString(0)
        }
        return null
    }

    private data class BackupRow(val uri: android.net.Uri, val name: String, val path: String)

    /// Restrict lookup to our folder and the old Downloads root. The latter is
    /// only read, never cleaned; MediaStore names are checked exactly in code,
    /// since SQL LIKE treats underscores in our prefix as wildcards.
    private fun backupRows(): List<BackupRow> {
        val rows = mutableListOf<BackupRow>()
        val cols = arrayOf(MediaStore.Downloads._ID, MediaStore.Downloads.DISPLAY_NAME, MediaStore.Downloads.RELATIVE_PATH)
        val sel = "${MediaStore.Downloads.RELATIVE_PATH} IN (?, ?)"
        contentResolver.query(MediaStore.Downloads.EXTERNAL_CONTENT_URI, cols, sel, arrayOf(BACKUP_PATH, "Download/"), null)?.use { c ->
            while (c.moveToNext()) {
                val name = c.getString(1) ?: continue
                if (name != BACKUP_NAME && name != BACKUP_JSON && !name.matches(LEGACY_ZIP) && !name.matches(PREVIOUS_ZIP)) continue
                rows.add(BackupRow(
                    android.net.Uri.withAppendedPath(MediaStore.Downloads.EXTERNAL_CONTENT_URI, c.getLong(0).toString()),
                    name,
                    c.getString(2) ?: "",
                ))
            }
        }
        return rows
    }

    private fun backupRead(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 29) {
            result.error("api", "MediaStore.Downloads needs api 29+", null)
            return
        }
        try {
            val rows = backupRows()
            val candidates = rows.filter { it.name == BACKUP_NAME && it.path == BACKUP_PATH } +
                rows.filter { it.name == BACKUP_NAME && it.path != BACKUP_PATH } +
                rows.filter { it.name.matches(LEGACY_ZIP) }.sortedByDescending { it.name } +
                rows.filter { it.name.matches(PREVIOUS_ZIP) } +
                rows.filter { it.name == BACKUP_JSON }
            for (row in candidates) {
                try {
                    val raw = contentResolver.openInputStream(row.uri)?.use { it.readBytes() }
                    if (raw != null) {
                        result.success(raw)
                        return
                    }
                } catch (_: Exception) {
                    // Try the next older readable archive.
                }
            }
            result.success(null)
        } catch (e: Exception) {
            result.error("io", e.message, null)
        }
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
        const val BACKUP_NAME = "paradise_autobackup.zip"
        const val BACKUP_JSON = "paradise_autobackup.json"
        const val BACKUP_PATH = "Download/Paradise/"
        val LEGACY_ZIP = Regex("paradise_autobackup-[0-9]{8}-[0-9]{6}\\.zip")
        val PREVIOUS_ZIP = Regex("paradise_autobackup-previous-[0-9a-f-]{36}\\.zip")
    }
}

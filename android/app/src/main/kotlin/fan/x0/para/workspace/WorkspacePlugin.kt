package fan.x0.para.workspace

import android.app.Activity
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.os.StatFs
import android.util.Log
import android.view.WindowManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/**
 * The native half of the workspace: proot execution, PTY sessions and rootfs
 * maintenance, all behind one method channel.
 *
 * The proot binaries are exec'd as separate processes rather than linked, which
 * is what keeps their GPL-2 terms from reaching this app. See
 * android/app/src/main/jniLibs/NOTICE.
 */
class WorkspacePlugin(private val context: Context) {
    private var attachedActivity: Activity? = null

    fun attachActivity(activity: Activity) {
        attachedActivity = activity
    }

    fun detachActivity(activity: Activity) {
        if (attachedActivity !== activity) return
        attachedActivity = null
    }

    companion object {
        const val CHANNEL_NAME = "app.workspace"
        const val EVENT_CHANNEL_NAME = "app.workspace/events"

        // A 32-bit APK runs fine on an ARM64 device. Match the app's own native
        // libraries rather than the device's preferred ABI when picking a rootfs,
        // or an arm64 rootfs lands beside 32-bit proot and nothing executes.
        internal fun runtimeAbi(
            is64Bit: Boolean = Process.is64Bit(),
            abis: Array<String> = Build.SUPPORTED_ABIS,
        ): String {
            val supported = if (is64Bit) listOf("arm64-v8a", "x86_64") else listOf("armeabi-v7a")
            return abis.firstOrNull { it in supported } ?: ""
        }
    }

    private val executor = Executors.newCachedThreadPool()

    /// Separate from [executor] so a rootfs extraction, which holds a thread for
    /// minutes, cannot starve the thread a terminal open needs.
    private val ptyExecutor = Executors.newCachedThreadPool()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val events = WorkspaceEvents()
    private val execRunner = ExecRunner(events)
    private val ptySessions = PtySessions(events)

    /// Set while the rootfs is being replaced. Every exec and PTY open is
    /// refused during that window rather than run against a half written tree.
    @Volatile
    private var environmentBusy = false

    fun configure(messenger: BinaryMessenger) {
        EventChannel(messenger, EVENT_CHANNEL_NAME).setStreamHandler(events)
        MethodChannel(messenger, CHANNEL_NAME).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "probe" -> result.success(probe())
                    "setEnvironmentBusy" -> {
                        environmentBusy = asMap(call.arguments)["busy"] == true
                        if (environmentBusy) {
                            execRunner.cancelAll()
                            ptySessions.closeAll()
                        }
                        result.success(null)
                    }
                    "inspectRootfs" -> runAsync(result, "invalid_rootfs") {
                        val args = asMap(call.arguments)
                        RootfsInfo.inspect(File(requiredString(args, "rootfsDir")), requiredString(args, "arch"))
                    }
                    "exec" -> {
                        require(!environmentBusy) { "environment is being replaced" }
                        exec(asMap(call.arguments))
                        result.success(mapOf("started" to true))
                    }
                    "stdinWrite" -> runAsync(result) {
                        val args = asMap(call.arguments)
                        execRunner.writeStdin(requiredString(args, "runId"), args["data"] as ByteArray)
                        null
                    }
                    "cancel" -> {
                        val runId = asMap(call.arguments)["runId"]?.toString().orEmpty()
                        result.success(runId.isNotEmpty() && execRunner.cancel(runId))
                    }
                    "ptyOpen" -> {
                        require(!environmentBusy) { "environment is being replaced" }
                        // Not on the platform thread. fork+execve of proot blocks
                        // for as long as the loader takes, and every pty event is
                        // posted back to this same thread: doing it inline means
                        // the first prompt is produced while the sink that has
                        // to deliver it is still busy being the caller.
                        val args = asMap(call.arguments)
                        runOn(ptyExecutor, result, "workspace") {
                            Log.i("WorkspacePty", "ptyOpen on worker busy=$environmentBusy")
                            val pid = try {
                                ptyOpen(args)
                            } catch (error: Throwable) {
                                Log.e("WorkspacePty", "ptyOpen failed", error)
                                throw error
                            }
                            Log.i("WorkspacePty", "ptyOpen returning pid=$pid")
                            mapOf("pid" to pid)
                        }
                    }
                    "ptyWrite" -> {
                        ptyWrite(asMap(call.arguments))
                        result.success(null)
                    }
                    "ptyResize" -> {
                        ptyResize(asMap(call.arguments))
                        result.success(null)
                    }
                    "ptyClose" -> {
                        val sessionId = asMap(call.arguments)["sessionId"]?.toString().orEmpty()
                        if (sessionId.isNotEmpty()) ptySessions.close(sessionId)
                        result.success(null)
                    }
                    "extractRootfs" -> runAsync(result) { extractRootfs(asMap(call.arguments)) }
                    "patchRootfs" -> runAsync(result) { patchRootfs(asMap(call.arguments)) }
                    "removeRootfs" -> runAsync(result) {
                        val dir = File(requiredString(asMap(call.arguments), "path"))
                        RootfsRemover.remove(dir)
                        mapOf("ok" to true)
                    }
                    "sha256File" -> runAsync(result) {
                        Sha256.file(asMap(call.arguments)["path"]?.toString().orEmpty())
                    }
                    "keepScreenOn" -> {
                        keepScreenOn(asMap(call.arguments)["enabled"] == true)
                        result.success(null)
                    }
                    "freeSpace" -> result.success(freeSpace(asMap(call.arguments)))
                    else -> result.notImplemented()
                }
            } catch (error: IllegalArgumentException) {
                result.error("invalid_args", error.message, null)
            } catch (error: Exception) {
                result.error("workspace", error.message, null)
            }
        }
    }

    fun dispose() {
        execRunner.cancelAll()
        ptySessions.closeAll()
        executor.shutdownNow()
        ptyExecutor.shutdownNow()
    }

    private fun probe(): Map<String, Any?> {
        val nativeLibDir = File(context.applicationInfo.nativeLibraryDir)
        val proot = File(nativeLibDir, ProotCommand.EXEC_LIB)
        val loader = File(nativeLibDir, ProotCommand.LOADER_LIB)
        // legacy packaging put them there executable, but a reinstall or a
        // restore-from-backup can drop the bit
        if (proot.isFile) proot.setExecutable(true, false)
        if (loader.isFile) loader.setExecutable(true, false)
        val supported = proot.isFile && proot.canExecute() && loader.isFile && loader.canExecute()
        val reason = when {
            supported -> null
            !proot.isFile -> "proot missing: ${proot.absolutePath}"
            !proot.canExecute() -> "proot not executable: ${proot.absolutePath}"
            !loader.isFile -> "loader missing: ${loader.absolutePath}"
            else -> "loader not executable: ${loader.absolutePath}"
        }
        return hashMapOf(
            "supported" to supported,
            "abi" to runtimeAbi(),
            "prootPath" to proot.takeIf { it.isFile }?.absolutePath,
            "loaderPath" to loader.takeIf { it.isFile }?.absolutePath,
            "nativeLibDir" to nativeLibDir.absolutePath,
            "reason" to reason,
        )
    }

    private fun exec(args: Map<*, *>) {
        execRunner.start(
            ExecRequest(
                runId = requiredString(args, "runId"),
                nativeLibDir = File(context.applicationInfo.nativeLibraryDir),
                rootfsDir = File(requiredString(args, "rootfsDir")),
                tmpDir = File(requiredString(args, "tmpDir")),
                binds = commandBinds(args),
                cwd = ProotCommand.validateGuestCwd(requiredString(args, "cwd")),
                command = requiredString(args, "command"),
                env = parseEnv(args["env"]),
                timeoutMs = number(args["timeoutMs"], 60_000L),
                keepStdinOpen = args["keepStdinOpen"] == true,
                prootArguments = parseStringList(args["prootArguments"]),
                shell = args["shell"]?.toString(),
            ),
        )
    }

    private fun ptyOpen(args: Map<*, *>): Int = ptySessions.open(
        sessionId = requiredString(args, "sessionId"),
        nativeLibDir = File(context.applicationInfo.nativeLibraryDir),
        rootfsDir = File(requiredString(args, "rootfsDir")),
        tmpDir = File(requiredString(args, "tmpDir")),
        binds = commandBinds(args),
        cwd = ProotCommand.validateGuestCwd(requiredString(args, "cwd")),
        env = parseEnv(args["env"]),
        cols = number(args["cols"], 80L).toInt(),
        rows = number(args["rows"], 24L).toInt(),
        prootArguments = parseStringList(args["prootArguments"]),
        shell = args["shell"]?.toString(),
    )

    private fun ptyWrite(args: Map<*, *>) {
        ptySessions.write(requiredString(args, "sessionId"), args["data"] as? ByteArray ?: ByteArray(0))
    }

    private fun ptyResize(args: Map<*, *>) {
        ptySessions.resize(
            sessionId = requiredString(args, "sessionId"),
            cols = number(args["cols"], 80L).toInt(),
            rows = number(args["rows"], 24L).toInt(),
        )
    }

    private fun extractRootfs(args: Map<*, *>): Map<String, Any> {
        val destDir = requiredString(args, "destDir")
        // throttled: a rootfs has 100k entries and emitting one event per entry
        // floods the channel faster than Dart can drain it
        var lastEmit = 0L
        RootfsExtractor.extract(
            archive = File(requiredString(args, "archivePath")),
            destDir = File(destDir),
            format = requiredString(args, "format"),
        ) { entries, bytes, currentEntry ->
            val now = System.currentTimeMillis()
            if (now - lastEmit < 200L && currentEntry.isNotEmpty()) return@extract
            lastEmit = now
            events.emit(
                hashMapOf(
                    "type" to "extract",
                    "destDir" to destDir,
                    "entries" to entries,
                    "bytes" to bytes,
                    "currentEntry" to currentEntry,
                ),
            )
        }
        return mapOf("ok" to true)
    }

    private fun patchRootfs(args: Map<*, *>): Map<String, Any> {
        RootfsPatcher.patch(
            rootfsDir = File(requiredString(args, "rootfsDir")),
            dnsServers = parseStringList(args["dnsServers"]),
            hostname = args["hostname"]?.toString()?.trim().orEmpty().ifBlank { "localhost" },
            aptMirrorBaseUrl = args["aptMirrorBaseUrl"]?.toString()?.trim()?.takeIf { it.isNotEmpty() },
            ubuntuCodename = args["ubuntuCodename"]?.toString().orEmpty(),
            arch = requiredString(args, "arch"),
        )
        return mapOf("ok" to true)
    }

    /// Free space on the volume holding [path], walking to the nearest existing
    /// ancestor because the installer asks about directories it has not made yet.
    private fun freeSpace(args: Map<*, *>): Map<String, Long> {
        val raw = requiredString(args, "path")
        var target = File(raw)
        while (!target.exists()) {
            target = target.parentFile
                ?: throw IllegalArgumentException("no existing ancestor for $raw")
        }
        val stat = StatFs(target.absolutePath)
        return mapOf("freeBytes" to stat.availableBytes, "totalBytes" to stat.totalBytes)
    }

    private fun keepScreenOn(enabled: Boolean) {
        val window = attachedActivity?.window ?: return
        if (enabled) {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }

    private fun runAsync(result: MethodChannel.Result, errorCode: String = "workspace", block: () -> Any?) {
        runOn(executor, result, errorCode, block)
    }

    private fun runOn(
        pool: java.util.concurrent.ExecutorService,
        result: MethodChannel.Result,
        errorCode: String,
        block: () -> Any?,
    ) {
        pool.execute {
            try {
                val value = block()
                mainHandler.post { result.success(value) }
            } catch (error: Exception) {
                mainHandler.post { result.error(errorCode, error.message, null) }
            }
        }
    }

    private fun asMap(value: Any?): Map<*, *> = value as? Map<*, *> ?: emptyMap<Any, Any>()

    private fun requiredString(args: Map<*, *>, key: String): String {
        val text = args[key]?.toString()?.trim().orEmpty()
        require(text.isNotEmpty()) { "missing $key" }
        return text
    }

    private fun number(value: Any?, fallback: Long): Long = when (value) {
        is Number -> value.toLong()
        is String -> value.toLongOrNull() ?: fallback
        else -> fallback
    }

    private fun parseEnv(raw: Any?): Map<String, String> {
        val map = raw as? Map<*, *> ?: return emptyMap()
        val out = LinkedHashMap<String, String>()
        for ((key, value) in map) {
            if (key == null || value == null) continue
            out[key.toString()] = value.toString()
        }
        return out
    }

    private fun parseStringList(raw: Any?): List<String> {
        val list = raw as? List<*> ?: return emptyList()
        return list.mapNotNull { it?.toString()?.trim()?.takeIf { item -> item.isNotEmpty() } }
    }

    private fun parseBinds(raw: Any?): List<BindMount> {
        val list = raw as? List<*> ?: return emptyList()
        return list.mapNotNull { item ->
            val map = item as? Map<*, *> ?: return@mapNotNull null
            val host = map["host"]?.toString().orEmpty()
            val guest = map["guest"]?.toString().orEmpty()
            if (host.isBlank() || guest.isBlank()) return@mapNotNull null
            BindMount(host, guest, map["readOnly"] == true)
        }
    }

    /// Every bind a command gets: the four built-in zones plus whatever the user
    /// linked. External mounts are appended by this method rather than accepted
    /// from Dart, so the Dart side cannot fabricate a host path bind.
    private fun commandBinds(args: Map<*, *>): List<BindMount> = parseBinds(args["binds"])
}
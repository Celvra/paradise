package fan.x0.para

import fan.x0.para.workspace.WorkspacePlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    /// Registered here rather than in an application class because the plugin
    /// needs an activity for FLAG_KEEP_SCREEN_ON and nothing else does.
    // Activity fields are initialized before Android attaches the base context.
    // Creating the plugin there makes applicationContext null on cold launch.
    private var workspacePlugin: WorkspacePlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val plugin = WorkspacePlugin(applicationContext)
        workspacePlugin = plugin
        plugin.configure(flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        workspacePlugin?.attachActivity(this)
    }

    override fun onDestroy() {
        workspacePlugin?.detachActivity(this)
        workspacePlugin = null
        super.onDestroy()
    }
}
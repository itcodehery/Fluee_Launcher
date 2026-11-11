package com.fluee.fluee_launcher

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var channel: MethodChannel? = null
    private var bridge: LauncherBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        val b = LauncherBridge(this)
        bridge = b

        channel = MethodChannel(messenger, LauncherBridge.METHOD_CHANNEL).also {
            it.setMethodCallHandler(b)
        }
        EventChannel(messenger, LauncherBridge.EVENT_CHANNEL).setStreamHandler(b)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        bridge?.handleActivityResult(requestCode, resultCode, data)
    }

    /** Home pressed while the launcher is already in front: let Dart reset its UI. */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.action == Intent.ACTION_MAIN && intent.hasCategory(Intent.CATEGORY_HOME)) {
            channel?.invokeMethod("onHomePressed", null)
        }
    }
}

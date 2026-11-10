package com.fluee.fluee_launcher

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        val bridge = LauncherBridge(applicationContext)

        channel = MethodChannel(messenger, LauncherBridge.METHOD_CHANNEL).also {
            it.setMethodCallHandler(bridge)
        }
        EventChannel(messenger, LauncherBridge.EVENT_CHANNEL).setStreamHandler(bridge)
    }

    /** Home pressed while the launcher is already in front: let Dart reset its UI. */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.action == Intent.ACTION_MAIN && intent.hasCategory(Intent.CATEGORY_HOME)) {
            channel?.invokeMethod("onHomePressed", null)
        }
    }
}

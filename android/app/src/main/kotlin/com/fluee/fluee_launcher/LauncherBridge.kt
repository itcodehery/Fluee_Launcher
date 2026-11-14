package com.fluee.fluee_launcher

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.LauncherApps
import android.content.pm.PackageManager
import android.content.res.Resources
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.graphics.Paint
import android.graphics.drawable.AdaptiveIconDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.os.UserHandle
import android.os.UserManager
import android.provider.AlarmClock
import android.provider.Settings
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.xmlpull.v1.XmlPullParser
import java.io.ByteArrayOutputStream
import java.util.Collections
import java.util.HashSet
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import kotlin.math.roundToInt

class LauncherBridge(private val context: Context) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val launcherApps = context.getSystemService(Context.LAUNCHER_APPS_SERVICE) as LauncherApps
    private val userManager = context.getSystemService(Context.USER_SERVICE) as UserManager
    private val mainHandler = Handler(Looper.getMainLooper())
    private val worker = Executors.newFixedThreadPool(2)

    private val iconPx: Int =
        (ICON_BITMAP_DP * context.resources.displayMetrics.density).roundToInt().coerceIn(96, 192)
    private val greyscale = ColorMatrixColorFilter(ColorMatrix().apply { setSaturation(0f) })

    private var packageCallback: LauncherApps.Callback? = null

    // In-memory cache of parsed icon pack drawables: map of packageName -> Map(componentName -> drawableName)
    private val iconPackCache = ConcurrentHashMap<String, Map<String, String>>()
    // Memory cache for rendered app icon PNG bytes: key is "$pkg/$activityName#$serial@$iconPack"
    private val renderedIconCache = ConcurrentHashMap<String, Pair<ByteArray, Boolean>>()

    // Media artwork cache: avoids re-encoding (and re-sending) unchanged album art every poll.
    private var artSourceRef: java.lang.ref.WeakReference<Bitmap>? = null
    private var artSourceBytes: ByteArray = ByteArray(0)
    private var lastSentArtId: Int = 0

    private var pendingExportContent: String? = null
    private var pendingExportResult: MethodChannel.Result? = null
    private var pendingImportResult: MethodChannel.Result? = null

    fun handleActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        when (requestCode) {
            REQUEST_CODE_CREATE_BACKUP -> {
                val res = pendingExportResult
                val content = pendingExportContent
                pendingExportResult = null
                pendingExportContent = null
                if (resultCode == android.app.Activity.RESULT_OK && data?.data != null && content != null) {
                    worker.execute {
                        try {
                            context.contentResolver.openOutputStream(data.data!!)?.use { os ->
                                os.write(content.toByteArray(Charsets.UTF_8))
                                os.flush()
                            }
                            mainHandler.post { res?.success(true) }
                        } catch (_: Exception) {
                            mainHandler.post { res?.success(false) }
                        }
                    }
                } else {
                    res?.success(false)
                }
                return true
            }
            REQUEST_CODE_OPEN_BACKUP -> {
                val res = pendingImportResult
                pendingImportResult = null
                if (resultCode == android.app.Activity.RESULT_OK && data?.data != null) {
                    worker.execute {
                        try {
                            val text = context.contentResolver.openInputStream(data.data!!)?.use { stream ->
                                stream.bufferedReader(Charsets.UTF_8).readText()
                            }
                            mainHandler.post { res?.success(text) }
                        } catch (_: Exception) {
                            mainHandler.post { res?.success(null) }
                        }
                    }
                } else {
                    res?.success(null)
                }
                return true
            }
        }
        return false
    }

    /**
     * Reads the currently active media session (preferring a playing/buffering one, then a
     * paused one so the now-playing tile does not flicker while paused), and falls back to the
     * media notification captured by [LauncherNotificationListener] when sessions are unavailable.
     *
     * Runs on the worker executor; never call from the main thread.
     */
    private fun readActiveMediaTrack(): Map<String, Any?>? {
        val playingStates = listOf(
            android.media.session.PlaybackState.STATE_PLAYING,
            android.media.session.PlaybackState.STATE_BUFFERING
        )

        try {
            val mediaSessionManager = context.getSystemService(Context.MEDIA_SESSION_SERVICE) as? android.media.session.MediaSessionManager
            if (mediaSessionManager != null) {
                val comp = ComponentName(context, LauncherNotificationListener::class.java)
                val controllers = mediaSessionManager.getActiveSessions(comp)
                val candidates = controllers.filter { ctrl ->
                    val state = ctrl.playbackState?.state
                    playingStates.contains(state) ||
                        state == android.media.session.PlaybackState.STATE_PAUSED
                }
                val active = candidates.firstOrNull { playingStates.contains(it.playbackState?.state) }
                    ?: candidates.firstOrNull()

                if (active != null) {
                    val metadata = active.metadata
                    val title = metadata?.getString(android.media.MediaMetadata.METADATA_KEY_TITLE)
                        ?: metadata?.getString(android.media.MediaMetadata.METADATA_KEY_DISPLAY_TITLE)
                    val artist = metadata?.getString(android.media.MediaMetadata.METADATA_KEY_ARTIST)
                        ?: metadata?.getString(android.media.MediaMetadata.METADATA_KEY_ALBUM_ARTIST)
                        ?: metadata?.getString(android.media.MediaMetadata.METADATA_KEY_AUTHOR)

                    if (!title.isNullOrEmpty()) {
                        val bitmap = metadata?.getBitmap(android.media.MediaMetadata.METADATA_KEY_ALBUM_ART)
                            ?: metadata?.getBitmap(android.media.MediaMetadata.METADATA_KEY_ART)
                            ?: metadata?.getBitmap(android.media.MediaMetadata.METADATA_KEY_DISPLAY_ICON)
                        return mediaPayload(
                            title = title,
                            artist = artist ?: "",
                            packageName = active.packageName ?: "",
                            isPlaying = playingStates.contains(active.playbackState?.state),
                            artBytes = encodeArt(bitmap)
                        )
                    }
                }
            }
        } catch (_: SecurityException) {
            // Notification Listener permission not granted yet
        } catch (_: Exception) {
        }

        // Fallback to active media notifications captured by listener service
        val fallback = LauncherNotificationListener.latestMediaNotification ?: return null
        if (fallback.title.isEmpty()) return null
        return mediaPayload(
            title = fallback.title,
            artist = fallback.artist,
            packageName = fallback.packageName,
            isPlaying = fallback.isPlaying,
            artBytes = fallback.artBytes
        )
    }

    /** Downscales/compresses album art, reusing the last result while the source bitmap is alive. */
    private fun encodeArt(source: Bitmap?): ByteArray {
        if (source == null) return ByteArray(0)
        if (artSourceRef?.get() === source) return artSourceBytes
        return try {
            val scaled = if (source.width > 192 || source.height > 192) {
                val ratio = minOf(192f / source.width, 192f / source.height)
                Bitmap.createScaledBitmap(
                    source,
                    (source.width * ratio).roundToInt().coerceAtLeast(1),
                    (source.height * ratio).roundToInt().coerceAtLeast(1),
                    true
                )
            } else {
                source
            }
            val bytes = ByteArrayOutputStream().use { stream ->
                scaled.compress(Bitmap.CompressFormat.JPEG, 85, stream)
                stream.toByteArray()
            }
            artSourceRef = java.lang.ref.WeakReference(source)
            artSourceBytes = bytes
            bytes
        } catch (_: Exception) {
            ByteArray(0)
        }
    }

    /**
     * Builds the channel payload for a track. Album art bytes are only included when the artwork
     * actually changed; Dart keeps the previously decoded image otherwise.
     */
    private fun mediaPayload(
        title: String,
        artist: String,
        packageName: String,
        isPlaying: Boolean,
        artBytes: ByteArray?
    ): Map<String, Any?> {
        val bytes = artBytes ?: ByteArray(0)
        val artId = if (bytes.isEmpty()) 0 else bytes.contentHashCode()
        val payload = mutableMapOf<String, Any?>(
            "title" to title,
            "artist" to artist,
            "packageName" to packageName,
            "isPlaying" to isPlaying,
            "artId" to artId
        )
        if (artId != lastSentArtId) {
            lastSentArtId = artId
            payload["albumArt"] = bytes
        }
        return payload
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getApps" -> {
                val iconPack = call.argument<String>("iconPack")
                val customMap = call.argument<Map<String, String>>("customIconMap") ?: emptyMap()
                worker.execute {
                    val apps = try {
                        loadApps(iconPack, customMap)
                    } catch (e: Exception) {
                        mainHandler.post { result.error("LOAD_FAILED", e.message, null) }
                        return@execute
                    }
                    mainHandler.post { result.success(apps) }
                }
            }

            "getAppIcon" -> {
                val packageName = call.argument<String>("packageName")!!
                val activityName = call.argument<String>("activityName")!!
                val userSerial = call.argument<Number>("userSerial")?.toLong() ?: 0L
                val iconPack = call.argument<String>("iconPack")
                val customDrawable = call.argument<String>("customDrawable")

                worker.execute {
                    try {
                        val iconData = renderSingleAppIcon(packageName, activityName, userSerial, iconPack, customDrawable)
                        mainHandler.post { result.success(iconData) }
                    } catch (e: Exception) {
                        mainHandler.post { result.error("ICON_FAILED", e.message, null) }
                    }
                }
            }

            "getIconPacks" -> worker.execute {
                val packs = try {
                    getAvailableIconPacks()
                } catch (e: Exception) {
                    emptyList<Map<String, Any>>()
                }
                mainHandler.post { result.success(packs) }
            }

            "getIconPackDrawables" -> {
                val packPackage = call.argument<String>("packageName")!!
                worker.execute {
                    val drawables = try {
                        getIconPackDrawableList(packPackage)
                    } catch (e: Exception) {
                        emptyList<Map<String, Any>>()
                    }
                    mainHandler.post { result.success(drawables) }
                }
            }

            "getVolume" -> {
                try {
                    val am = context.getSystemService(Context.AUDIO_SERVICE) as android.media.AudioManager
                    val max = am.getStreamMaxVolume(android.media.AudioManager.STREAM_MUSIC).coerceAtLeast(1)
                    result.success(am.getStreamVolume(android.media.AudioManager.STREAM_MUSIC).toDouble() / max)
                } catch (_: Exception) {
                    result.success(null)
                }
            }

            "setVolume" -> {
                try {
                    val fraction = (call.argument<Number>("value")?.toDouble() ?: 0.0).coerceIn(0.0, 1.0)
                    val am = context.getSystemService(Context.AUDIO_SERVICE) as android.media.AudioManager
                    val max = am.getStreamMaxVolume(android.media.AudioManager.STREAM_MUSIC)
                    am.setStreamVolume(
                        android.media.AudioManager.STREAM_MUSIC,
                        (fraction * max).roundToInt().coerceIn(0, max),
                        0
                    )
                    result.success(true)
                } catch (_: Exception) {
                    result.success(false)
                }
            }

            "getBrightness" -> {
                try {
                    val v = Settings.System.getInt(context.contentResolver, Settings.System.SCREEN_BRIGHTNESS, 128)
                    result.success(v / 255.0)
                } catch (_: Exception) {
                    result.success(null)
                }
            }

            "canWriteSettings" -> {
                result.success(Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.System.canWrite(context))
            }

            "openWriteSettings" -> {
                startSafely(
                    Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS, Uri.parse("package:" + context.packageName))
                )
                result.success(null)
            }

            "setWindowDim" -> {
                val dimmed = call.argument<Boolean>("dimmed") ?: false
                val activity = context as? android.app.Activity
                if (activity != null) {
                    mainHandler.post {
                        val params = activity.window.attributes
                        params.screenBrightness = if (dimmed) {
                            0.04f
                        } else {
                            android.view.WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                        }
                        activity.window.attributes = params
                    }
                    result.success(true)
                } else {
                    result.success(false)
                }
            }

            "setBrightness" -> {
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.System.canWrite(context)) {
                        result.success(false)
                    } else {
                        val fraction = (call.argument<Number>("value")?.toDouble() ?: 0.5).coerceIn(0.0, 1.0)
                        Settings.System.putInt(
                            context.contentResolver,
                            Settings.System.SCREEN_BRIGHTNESS_MODE,
                            Settings.System.SCREEN_BRIGHTNESS_MODE_MANUAL
                        )
                        Settings.System.putInt(
                            context.contentResolver,
                            Settings.System.SCREEN_BRIGHTNESS,
                            (fraction * 255).roundToInt().coerceIn(1, 255)
                        )
                        result.success(true)
                    }
                } catch (_: Exception) {
                    result.success(false)
                }
            }

            "getBatteryLevel" -> {
                try {
                    val intent = context.registerReceiver(null, android.content.IntentFilter(Intent.ACTION_BATTERY_CHANGED))
                    val level = intent?.getIntExtra(android.os.BatteryManager.EXTRA_LEVEL, -1) ?: -1
                    val scale = intent?.getIntExtra(android.os.BatteryManager.EXTRA_SCALE, -1) ?: -1
                    val status = intent?.getIntExtra(android.os.BatteryManager.EXTRA_STATUS, -1) ?: -1
                    val charging = status == android.os.BatteryManager.BATTERY_STATUS_CHARGING ||
                        status == android.os.BatteryManager.BATTERY_STATUS_FULL
                    if (level >= 0 && scale > 0) {
                        result.success(mapOf("level" to (level * 100 / scale), "charging" to charging))
                    } else {
                        result.success(null)
                    }
                } catch (_: Exception) {
                    result.success(null)
                }
            }

            "isBluetoothConnected" -> {
                try {
                    val btManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? android.bluetooth.BluetoothManager
                    val adapter = btManager?.adapter
                    if (adapter == null || !adapter.isEnabled) {
                        result.success(false)
                    } else {
                        val a2dp = try {
                            adapter.getProfileConnectionState(android.bluetooth.BluetoothProfile.A2DP) == android.bluetooth.BluetoothProfile.STATE_CONNECTED
                        } catch (_: SecurityException) { false }
                        val headset = try {
                            adapter.getProfileConnectionState(android.bluetooth.BluetoothProfile.HEADSET) == android.bluetooth.BluetoothProfile.STATE_CONNECTED
                        } catch (_: SecurityException) { false }
                        val gatt = try {
                            adapter.getProfileConnectionState(android.bluetooth.BluetoothProfile.GATT) == android.bluetooth.BluetoothProfile.STATE_CONNECTED
                        } catch (_: SecurityException) { false }
                        val bondedConnected = try {
                            // Check bonded devices for active connection methods
                            adapter.bondedDevices?.any { dev ->
                                try {
                                    val isConnectedMethod = dev.javaClass.getMethod("isConnected")
                                    isConnectedMethod.invoke(dev) as? Boolean ?: false
                                } catch (_: Exception) { false }
                            } ?: false
                        } catch (_: SecurityException) { false }
                        result.success(a2dp || headset || gatt || bondedConnected)
                    }
                } catch (_: Exception) {
                    result.success(false)
                }
            }

            "openNotifications" -> {
                var ok = false
                try {
                    val sbService = context.getSystemService("statusbar")
                    val statusBarManager = Class.forName("android.app.StatusBarManager")
                    val method = statusBarManager.getMethod("expandNotificationsPanel")
                    method.invoke(sbService)
                    ok = true
                } catch (_: Exception) {}
                result.success(ok)
            }

            "isNotificationAccessGranted" -> {
                val flat = Settings.Secure.getString(context.contentResolver, "enabled_notification_listeners")
                val pkgName = context.packageName
                val granted = flat != null && flat.contains(pkgName)
                result.success(granted)
            }

            "getMediaTrack" -> {
                worker.execute {
                    val track = try {
                        readActiveMediaTrack()
                    } catch (_: Exception) {
                        null
                    }
                    mainHandler.post { result.success(track) }
                }
            }

            "openNotificationListenerSettings" -> {
                try {
                    context.startActivity(
                        Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    )
                } catch (_: Exception) {}
                result.success(null)
            }

            "launch" -> {
                val component = call.component()
                val user = call.user()
                try {
                    launcherApps.startMainActivity(component, user, null, null)
                } catch (_: Exception) {
                    context.packageManager.getLaunchIntentForPackage(component.packageName)
                        ?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        ?.let(context::startActivity)
                }
                result.success(null)
            }

            "appInfo" -> {
                val component = call.component()
                try {
                    launcherApps.startAppDetailsActivity(component, call.user(), null, null)
                } catch (_: Exception) {
                    startSafely(
                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                            .setData(Uri.fromParts("package", component.packageName, null))
                    )
                }
                result.success(null)
            }

            "uninstall" -> {
                startSafely(
                    Intent(Intent.ACTION_DELETE)
                        .setData(Uri.fromParts("package", call.argument<String>("packageName"), null))
                )
                result.success(null)
            }

            "openAlarms" -> {
                startSafely(Intent(AlarmClock.ACTION_SHOW_ALARMS))
                result.success(null)
            }

            "openCalendar" -> {
                val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_APP_CALENDAR)
                startSafely(intent)
                result.success(null)
            }

            "openHomeSettings" -> {
                startSafely(Intent(Settings.ACTION_HOME_SETTINGS))
                result.success(null)
            }

            "getShortcuts" -> {
                val packageName = call.argument<String>("packageName")
                val user = call.user()
                worker.execute {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N_MR1 && launcherApps.hasShortcutHostPermission()) {
                            val query = LauncherApps.ShortcutQuery().apply {
                                setQueryFlags(
                                    LauncherApps.ShortcutQuery.FLAG_MATCH_DYNAMIC or
                                    LauncherApps.ShortcutQuery.FLAG_MATCH_MANIFEST or
                                    LauncherApps.ShortcutQuery.FLAG_MATCH_PINNED
                                )
                                if (!packageName.isNullOrEmpty()) {
                                    setPackage(packageName)
                                }
                            }
                            val shortcuts = launcherApps.getShortcuts(query, user) ?: emptyList()
                            val list = shortcuts.mapNotNull { s ->
                                val id = s.id
                                val pkg = s.`package`
                                val shortLabel = s.shortLabel?.toString() ?: s.longLabel?.toString() ?: ""
                                val longLabel = s.longLabel?.toString() ?: shortLabel
                                if (shortLabel.isEmpty()) return@mapNotNull null
                                val drawable = try {
                                    launcherApps.getShortcutIconDrawable(s, context.resources.displayMetrics.densityDpi)
                                } catch (_: Exception) { null }
                                val iconBytes = drawable?.let { d ->
                                    val bmp = Bitmap.createBitmap(iconPx, iconPx, Bitmap.Config.ARGB_8888)
                                    val c = Canvas(bmp)
                                    d.setBounds(0, 0, iconPx, iconPx)
                                    d.draw(c)
                                    val stream = ByteArrayOutputStream()
                                    bmp.compress(Bitmap.CompressFormat.PNG, 100, stream)
                                    stream.toByteArray()
                                }
                                mapOf(
                                    "id" to id,
                                    "packageName" to pkg,
                                    "shortLabel" to shortLabel,
                                    "longLabel" to longLabel,
                                    "icon" to (iconBytes ?: ByteArray(0))
                                )
                            }
                            mainHandler.post { result.success(list) }
                        } else {
                            mainHandler.post { result.success(emptyList<Map<String, Any>>()) }
                        }
                    } catch (_: Exception) {
                        mainHandler.post { result.success(emptyList<Map<String, Any>>()) }
                    }
                }
            }

            "startShortcut" -> {
                val packageName = call.argument<String>("packageName") ?: ""
                val shortcutId = call.argument<String>("shortcutId") ?: ""
                val user = call.user()
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N_MR1) {
                        launcherApps.startShortcut(packageName, shortcutId, null, null, user)
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                } catch (e: Exception) {
                    result.error("SHORTCUT_FAILED", e.message, null)
                }
            }

            "exportBackupFile" -> {
                val content = call.argument<String>("content") ?: ""
                val fileName = call.argument<String>("fileName") ?: "fluee_backup_${System.currentTimeMillis()}.json"
                val act = context as? android.app.Activity
                if (act != null) {
                    pendingExportContent = content
                    pendingExportResult = result
                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "application/json"
                        putExtra(Intent.EXTRA_TITLE, fileName)
                    }
                    try {
                        act.startActivityForResult(intent, REQUEST_CODE_CREATE_BACKUP)
                    } catch (e: Exception) {
                        pendingExportResult = null
                        pendingExportContent = null
                        result.error("EXPORT_FAILED", e.message, null)
                    }
                } else {
                    result.error("NO_ACTIVITY", "Activity not available for file picker", null)
                }
            }

            "importBackupFile" -> {
                val act = context as? android.app.Activity
                if (act != null) {
                    pendingImportResult = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "*/*"
                        putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/json", "text/plain"))
                    }
                    try {
                        act.startActivityForResult(intent, REQUEST_CODE_OPEN_BACKUP)
                    } catch (e: Exception) {
                        pendingImportResult = null
                        result.error("IMPORT_FAILED", e.message, null)
                    }
                } else {
                    result.error("NO_ACTIVITY", "Activity not available for file picker", null)
                }
            }

            "shareBackup" -> {
                val content = call.argument<String>("content") ?: ""
                val title = call.argument<String>("title") ?: "Fluee Launcher Backup"
                try {
                    val intent = Intent(Intent.ACTION_SEND).apply {
                        type = "text/plain"
                        putExtra(Intent.EXTRA_SUBJECT, title)
                        putExtra(Intent.EXTRA_TEXT, content)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    val chooser = Intent.createChooser(intent, "Share Fluee Backup").apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    context.startActivity(chooser)
                    result.success(true)
                } catch (_: Exception) {
                    result.success(false)
                }
            }

            "wallpaperAccent" -> {
                val color = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    context.getColor(android.R.color.system_accent1_200).toLong() and 0xFFFFFFFFL
                } else {
                    null
                }
                result.success(color)
            }

            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        val callback = object : LauncherApps.Callback() {
            override fun onPackageAdded(packageName: String, user: UserHandle) {
                renderedIconCache.clear()
                events.success(packageName)
            }
            override fun onPackageRemoved(packageName: String, user: UserHandle) {
                renderedIconCache.clear()
                events.success(packageName)
            }
            override fun onPackageChanged(packageName: String, user: UserHandle) {
                renderedIconCache.clear()
                events.success(packageName)
            }
            override fun onPackagesAvailable(names: Array<out String>?, user: UserHandle, replacing: Boolean) {
                renderedIconCache.clear()
                events.success(null)
            }
            override fun onPackagesUnavailable(names: Array<out String>?, user: UserHandle, replacing: Boolean) {
                renderedIconCache.clear()
                events.success(null)
            }
        }
        packageCallback = callback
        launcherApps.registerCallback(callback, mainHandler)
    }

    override fun onCancel(arguments: Any?) {
        packageCallback?.let(launcherApps::unregisterCallback)
        packageCallback = null
    }

    private fun loadApps(
        globalIconPack: String?,
        customMap: Map<String, String>
    ): List<Map<String, Any>> {
        val profiles = try {
            userManager.userProfiles
        } catch (_: Exception) {
            listOf(Process.myUserHandle())
        }
        val density = context.resources.displayMetrics.densityDpi
        val apps = mutableListOf<Map<String, Any>>()
        val seen = HashSet<String>()

        val iconPackMap = if (!globalIconPack.isNullOrEmpty()) {
            getOrParseIconPack(globalIconPack)
        } else {
            emptyMap()
        }

        for (profile in profiles) {
            val serial = userManager.getSerialNumberForUser(profile)
            val activities = try {
                launcherApps.getActivityList(null, profile)
            } catch (_: Exception) {
                emptyList()
            }
            for (activity in activities) {
                val pkg = activity.applicationInfo.packageName
                if (pkg == context.packageName) continue

                val id = "$pkg/${activity.name}#$serial"
                if (!seen.add(id)) continue

                // Check custom icon first, then icon pack, else system
                val customSpec = customMap[id] // format: "packPackage/drawableName"
                val (png, monochrome) = resolveAppIcon(activity, density, id, globalIconPack, iconPackMap, customSpec)

                apps += mapOf(
                    "label" to activity.label.toString(),
                    "packageName" to pkg,
                    "activityName" to activity.name,
                    "userSerial" to serial,
                    "icon" to png,
                    "monochrome" to monochrome
                )
            }
        }
        return apps
    }

    private fun resolveAppIcon(
        activity: android.content.pm.LauncherActivityInfo,
        density: Int,
        id: String,
        iconPackPackage: String?,
        iconPackMap: Map<String, String>,
        customSpec: String?
    ): Pair<ByteArray, Boolean> {
        val cacheKey = "$id@$iconPackPackage@$customSpec"
        renderedIconCache[cacheKey]?.let {
            return it
        }

        // 1. Try Custom Spec ("pack/drawable")
        if (!customSpec.isNullOrEmpty()) {
            val parts = customSpec.split("/")
            if (parts.size == 2) {
                val packPkg = parts[0]
                val drawableName = parts[1]
                val drawable = loadDrawableFromPack(packPkg, drawableName)
                if (drawable != null) {
                    val pair = renderIconGlyph(drawable)
                    renderedIconCache[cacheKey] = pair
                    return pair
                }
            }
        }

        // 2. Try Global Icon Pack
        if (!iconPackPackage.isNullOrEmpty() && iconPackMap.isNotEmpty()) {
            val compKey = "ComponentInfo{${activity.applicationInfo.packageName}/${activity.name}}"
            val drawableName = iconPackMap[compKey]
            if (drawableName != null) {
                val drawable = loadDrawableFromPack(iconPackPackage, drawableName)
                if (drawable != null) {
                    val pair = renderIconGlyph(drawable)
                    renderedIconCache[cacheKey] = pair
                    return pair
                }
            }
        }

        // 3. Fallback to System Launcher Icon
        val systemDrawable = try {
            activity.getIcon(density)
        } catch (_: Exception) {
            null
        } ?: context.packageManager.defaultActivityIcon

        val pair = renderIconGlyph(systemDrawable)
        renderedIconCache[cacheKey] = pair
        return pair
    }

    private fun renderSingleAppIcon(
        packageName: String,
        activityName: String,
        userSerial: Long,
        iconPack: String?,
        customSpec: String?
    ): Map<String, Any> {
        val user = userManager.getUserForSerialNumber(userSerial) ?: Process.myUserHandle()
        val density = context.resources.displayMetrics.densityDpi
        val activities = launcherApps.getActivityList(packageName, user)
        val activity = activities.firstOrNull { it.name == activityName }
            ?: activities.firstOrNull()
            ?: throw Exception("Activity not found")

        val id = "$packageName/$activityName#$userSerial"
        val iconPackMap = if (!iconPack.isNullOrEmpty()) getOrParseIconPack(iconPack) else emptyMap()
        val (bytes, mono) = resolveAppIcon(activity, density, id, iconPack, iconPackMap, customSpec)
        return mapOf("icon" to bytes, "monochrome" to mono)
    }

    private fun renderIconGlyph(drawable: Drawable): Pair<ByteArray, Boolean> {
        val n = iconPx
        val bitmap = Bitmap.createBitmap(n, n, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        var monochrome = false

        val adaptiveLayer = if (drawable is AdaptiveIconDrawable) {
            val mono = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) drawable.monochrome else null
            monochrome = mono != null
            (mono ?: drawable.foreground)?.mutate()
        } else {
            null
        }

        if (adaptiveLayer != null) {
            adaptiveLayer.setBounds(-n / 4, -n / 4, n + n / 4, n + n / 4)
            adaptiveLayer.draw(canvas)
        } else {
            monochrome = false
            val legacy = drawable.mutate()
            val inset = n / 8
            legacy.setBounds(inset, inset, n - inset, n - inset)
            legacy.draw(canvas)
        }

        // If not already an official monochrome vector layer, apply desaturated monochrome filter to the bitmap
        val finalBitmap: Bitmap
        if (!monochrome) {
            val desaturated = Bitmap.createBitmap(n, n, Bitmap.Config.ARGB_8888)
            val desaturatedCanvas = Canvas(desaturated)
            val paint = Paint().apply {
                colorFilter = greyscale
            }
            desaturatedCanvas.drawBitmap(bitmap, 0f, 0f, paint)
            bitmap.recycle()
            finalBitmap = desaturated
        } else {
            finalBitmap = bitmap
        }

        val out = ByteArrayOutputStream()
        finalBitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
        finalBitmap.recycle()
        return out.toByteArray() to monochrome
    }

    private fun getAvailableIconPacks(): List<Map<String, Any>> {
        val pm = context.packageManager
        val intents = listOf(
            Intent("org.adw.launcher.THEMES"),
            Intent("com.novalauncher.THEME"),
            Intent("com.gau.go.launcherex.theme")
        )
        val seenPackages = HashSet<String>()
        val packs = mutableListOf<Map<String, Any>>()

        for (intent in intents) {
            val resolveInfos = pm.queryIntentActivities(intent, PackageManager.GET_META_DATA)
            for (info in resolveInfos) {
                val pkg = info.activityInfo.packageName
                if (seenPackages.add(pkg)) {
                    val label = info.loadLabel(pm).toString()
                    val iconDrawable = info.loadIcon(pm)
                    val (iconBytes, _) = renderIconGlyph(iconDrawable)
                    packs += mapOf(
                        "packageName" to pkg,
                        "label" to label,
                        "icon" to iconBytes
                    )
                }
            }
        }
        return packs
    }

    private fun getOrParseIconPack(packPackage: String): Map<String, String> {
        iconPackCache[packPackage]?.let { return it }

        val map = HashMap<String, String>()
        try {
            val pm = context.packageManager
            val res = pm.getResourcesForApplication(packPackage)
            val appfilterId = res.getIdentifier("appfilter", "xml", packPackage)
            if (appfilterId != 0) {
                val parser = res.getXml(appfilterId)
                var eventType = parser.eventType
                while (eventType != XmlPullParser.END_DOCUMENT) {
                    if (eventType == XmlPullParser.START_TAG && parser.name == "item") {
                        val component = parser.getAttributeValue(null, "component")
                        val drawable = parser.getAttributeValue(null, "drawable")
                        if (!component.isNullOrEmpty() && !drawable.isNullOrEmpty()) {
                            map[component] = drawable
                        }
                    }
                    eventType = parser.next()
                }
            }
        } catch (_: Exception) {}

        iconPackCache[packPackage] = map
        return map
    }

    private fun getIconPackDrawableList(packPackage: String): List<Map<String, Any>> {
        val map = getOrParseIconPack(packPackage)
        val drawables = mutableListOf<Map<String, Any>>()
        val seenDrawables = HashSet<String>()

        for ((_, drawableName) in map) {
            if (seenDrawables.add(drawableName)) {
                val drawable = loadDrawableFromPack(packPackage, drawableName) ?: continue
                val (bytes, _) = renderIconGlyph(drawable)
                drawables += mapOf(
                    "drawableName" to drawableName,
                    "icon" to bytes
                )
                if (drawables.size >= 120) break // limit for fast sheet display
            }
        }
        return drawables
    }

    private fun loadDrawableFromPack(packPackage: String, drawableName: String): Drawable? {
        return try {
            val res = context.packageManager.getResourcesForApplication(packPackage)
            val id = res.getIdentifier(drawableName, "drawable", packPackage)
            if (id != 0) res.getDrawable(id, null) else null
        } catch (_: Exception) {
            null
        }
    }

    private fun MethodCall.component(): ComponentName =
        ComponentName(argument<String>("packageName")!!, argument<String>("activityName")!!)

    private fun MethodCall.user(): UserHandle {
        val serial = argument<Number>("userSerial")?.toLong()
        return serial?.let { userManager.getUserForSerialNumber(it) } ?: Process.myUserHandle()
    }

    private fun startSafely(intent: Intent) {
        try {
            context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        } catch (_: Exception) { }
    }

    companion object {
        const val METHOD_CHANNEL = "fluee/launcher"
        const val EVENT_CHANNEL = "fluee/app_changes"
        private const val ICON_BITMAP_DP = 64f
        const val REQUEST_CODE_CREATE_BACKUP = 2001
        const val REQUEST_CODE_OPEN_BACKUP = 2002
    }
}

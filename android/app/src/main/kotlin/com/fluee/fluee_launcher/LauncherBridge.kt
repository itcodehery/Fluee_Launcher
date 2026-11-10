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
    private var isTorchOn: Boolean = false

    private var packageCallback: LauncherApps.Callback? = null

    // In-memory cache of parsed icon pack drawables: map of packageName -> Map(componentName -> drawableName)
    private val iconPackCache = ConcurrentHashMap<String, Map<String, String>>()
    // Memory cache for rendered app icon PNG bytes: key is "$pkg/$activityName#$serial@$iconPack"
    private val renderedIconCache = ConcurrentHashMap<String, Pair<ByteArray, Boolean>>()

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

            "isAccessibilityServiceEnabled" -> {
                result.success(LauncherAccessibilityService.instance != null)
            }

            "openAccessibilitySettings" -> {
                var opened = false
                try {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    context.startActivity(intent)
                    opened = true
                } catch (_: Exception) {
                    try {
                        val fallback = Intent(Settings.ACTION_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        context.startActivity(fallback)
                        opened = true
                    } catch (_: Exception) {}
                }
                result.success(opened)
            }

            "openWifiSettings" -> {
                startSafely(Intent(Settings.ACTION_WIFI_SETTINGS))
                result.success(null)
            }

            "openSoundSettings" -> {
                startSafely(Intent(Settings.ACTION_SOUND_SETTINGS))
                result.success(null)
            }

            "openBatterySettings" -> {
                try {
                    context.startActivity(
                        Intent(Intent.ACTION_POWER_USAGE_SUMMARY)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    )
                } catch (_: Exception) {
                    startSafely(Intent(Settings.ACTION_BATTERY_SAVER_SETTINGS))
                }
                result.success(null)
            }

            "openAirplaneSettings" -> {
                startSafely(Intent(Settings.ACTION_AIRPLANE_MODE_SETTINGS))
                result.success(null)
            }

            "openDisplaySettings" -> {
                startSafely(Intent(Settings.ACTION_DISPLAY_SETTINGS))
                result.success(null)
            }

            "openDndSettings" -> {
                startSafely(Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS))
                result.success(null)
            }

            "openSystemSettings" -> {
                startSafely(Intent(Settings.ACTION_SETTINGS))
                result.success(null)
            }

            "openAutoRotateSettings" -> {
                startSafely(Intent(Settings.ACTION_AUTO_ROTATE_SETTINGS))
                result.success(null)
            }

            "openNightLightSettings" -> {
                try {
                    context.startActivity(
                        Intent(Settings.ACTION_NIGHT_DISPLAY_SETTINGS)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    )
                } catch (_: Exception) {
                    startSafely(Intent(Settings.ACTION_DISPLAY_SETTINGS))
                }
                result.success(null)
            }

            "openCamera" -> {
                startSafely(Intent(android.provider.MediaStore.INTENT_ACTION_STILL_IMAGE_CAMERA))
                result.success(null)
            }

            "openBluetoothSettings" -> {
                startSafely(Intent(Settings.ACTION_BLUETOOTH_SETTINGS))
                result.success(null)
            }

            "isAirplaneModeOn" -> {
                try {
                    val state = Settings.Global.getInt(
                        context.contentResolver,
                        Settings.Global.AIRPLANE_MODE_ON,
                        0
                    )
                    result.success(state != 0)
                } catch (_: Exception) {
                    result.success(false)
                }
            }

            "isWifiEnabled" -> {
                try {
                    val wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as? android.net.wifi.WifiManager
                    result.success(wifiManager?.isWifiEnabled ?: false)
                } catch (_: Exception) {
                    result.success(false)
                }
            }

            "isAutoRotateOn" -> {
                try {
                    val state = Settings.System.getInt(
                        context.contentResolver,
                        Settings.System.ACCELEROMETER_ROTATION,
                        0
                    )
                    result.success(state == 1)
                } catch (_: Exception) {
                    result.success(true)
                }
            }

            "isDndOn" -> {
                try {
                    val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? android.app.NotificationManager
                    val filter = nm?.currentInterruptionFilter
                    result.success(filter != null && filter != android.app.NotificationManager.INTERRUPTION_FILTER_ALL)
                } catch (_: Exception) {
                    result.success(false)
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

            "toggleFlashlight" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    val cm = context.getSystemService(Context.CAMERA_SERVICE) as? android.hardware.camera2.CameraManager
                    if (cm != null) {
                        try {
                            val cameraId = cm.cameraIdList.firstOrNull()
                            if (cameraId != null) {
                                isTorchOn = !isTorchOn
                                cm.setTorchMode(cameraId, isTorchOn)
                                result.success(isTorchOn)
                                return
                            }
                        } catch (_: Exception) {}
                    }
                }
                result.success(false)
            }

            "lockScreen" -> {
                val locked = LauncherAccessibilityService.lockScreen()
                result.success(locked)
            }

            "isNotificationAccessGranted" -> {
                val flat = Settings.Secure.getString(context.contentResolver, "enabled_notification_listeners")
                val pkgName = context.packageName
                val granted = flat != null && flat.contains(pkgName)
                result.success(granted)
            }

            "getMediaTrack" -> {
                try {
                    val mediaSessionManager = context.getSystemService(Context.MEDIA_SESSION_SERVICE) as? android.media.session.MediaSessionManager
                    if (mediaSessionManager != null) {
                        val comp = ComponentName(context, LauncherNotificationListener::class.java)
                        val controllers = mediaSessionManager.getActiveSessions(comp)
                        val active = controllers.firstOrNull { ctrl ->
                            val state = ctrl.playbackState?.state
                            state == android.media.session.PlaybackState.STATE_PLAYING ||
                            state == android.media.session.PlaybackState.STATE_BUFFERING
                        } ?: controllers.firstOrNull()

                        if (active != null) {
                            val metadata = active.metadata
                            val title = metadata?.getString(android.media.MediaMetadata.METADATA_KEY_TITLE)
                                ?: metadata?.getString(android.media.MediaMetadata.METADATA_KEY_DISPLAY_TITLE)
                            val artist = metadata?.getString(android.media.MediaMetadata.METADATA_KEY_ARTIST)
                                ?: metadata?.getString(android.media.MediaMetadata.METADATA_KEY_ALBUM_ARTIST)
                                ?: metadata?.getString(android.media.MediaMetadata.METADATA_KEY_AUTHOR)

                            if (!title.isNullOrEmpty()) {
                                result.success(
                                    mapOf(
                                        "title" to title,
                                        "artist" to (artist ?: ""),
                                        "isPlaying" to (active.playbackState?.state == android.media.session.PlaybackState.STATE_PLAYING)
                                    )
                                )
                                return
                            }
                        }
                    }
                } catch (_: SecurityException) {
                    // Notification Listener permission not granted yet
                } catch (_: Exception) {}

                // Fallback to active media notifications captured by listener service
                val fallback = LauncherNotificationListener.latestMediaNotification
                if (fallback != null && fallback.title.isNotEmpty()) {
                    result.success(
                        mapOf(
                            "title" to fallback.title,
                            "artist" to fallback.artist,
                            "isPlaying" to fallback.isPlaying
                        )
                    )
                    return
                }

                result.success(null)
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
    }
}

package com.fluee.fluee_launcher

import android.app.Notification
import android.graphics.Bitmap
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import java.io.ByteArrayOutputStream
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Service allowing Fluee Launcher to read active media sessions
 * and fallback to active media notifications when Notification Access is granted.
 */
class LauncherNotificationListener : NotificationListenerService() {

    companion object {
        private const val ART_MAX_PX = 192

        @Volatile
        var isConnected: Boolean = false
            private set

        @Volatile
        var latestMediaNotification: MediaTrackInfo? = null
            private set

        // Large icons are re-rasterized only when the track actually changes; media
        // notifications post frequently (progress updates) with the same artwork.
        private var artCacheKey: String? = null
        private var artCacheBytes: ByteArray? = null

        data class MediaTrackInfo(
            val title: String,
            val artist: String,
            val packageName: String,
            val isPlaying: Boolean,
            val artBytes: ByteArray?
        )
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        isConnected = true
        scanActiveMediaNotifications()
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        isConnected = false
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        checkAndUpdateMediaNotification(sbn)
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        super.onNotificationRemoved(sbn)
        if (latestMediaNotification?.packageName == sbn?.packageName) {
            latestMediaNotification = null
            scanActiveMediaNotifications()
        }
    }

    private fun checkAndUpdateMediaNotification(sbn: StatusBarNotification?) {
        if (sbn == null) return
        val extras = sbn.notification.extras ?: return
        if (!isMediaNotification(sbn.notification, extras)) return

        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()
        val artist = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
            ?: extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString()

        if (!title.isNullOrEmpty()) {
            latestMediaNotification = MediaTrackInfo(
                title = title,
                artist = artist ?: "",
                packageName = sbn.packageName,
                isPlaying = isPlayingFromSession(extras),
                artBytes = artBytesFor(sbn, title, artist ?: "")
            )
        }
    }

    private fun scanActiveMediaNotifications() {
        try {
            val active = activeNotifications ?: return
            for (sbn in active) {
                val extras = sbn.notification.extras ?: continue
                if (!isMediaNotification(sbn.notification, extras)) continue

                val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()
                val artist = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
                    ?: extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString()
                if (!title.isNullOrEmpty()) {
                    latestMediaNotification = MediaTrackInfo(
                        title = title,
                        artist = artist ?: "",
                        packageName = sbn.packageName,
                        isPlaying = isPlayingFromSession(extras),
                        artBytes = artBytesFor(sbn, title, artist ?: "")
                    )
                    return
                }
            }
        } catch (_: Exception) {}
    }

    /**
     * Resolves the real playback state from the notification's media session.
     * Only defaults to "playing" when the notification exposes no session at all.
     */
    private fun isPlayingFromSession(extras: android.os.Bundle): Boolean {
        val token = extras.getParcelable<MediaSession.Token>(Notification.EXTRA_MEDIA_SESSION)
            ?: return true
        return try {
            val controller = android.media.session.MediaController(this, token)
            val state = controller.playbackState?.state
            state == PlaybackState.STATE_PLAYING || state == PlaybackState.STATE_BUFFERING
        } catch (_: Exception) {
            true
        }
    }

    /** Reuses the last rasterized artwork while the same track stays in the notification. */
    private fun artBytesFor(sbn: StatusBarNotification, title: String, artist: String): ByteArray? {
        val key = "${sbn.packageName}|${sbn.id}|$title|$artist"
        if (key == artCacheKey) return artCacheBytes
        val bytes = artBytesFrom(sbn.notification)
        artCacheKey = key
        artCacheBytes = bytes
        return bytes
    }

    private fun artBytesFrom(notification: Notification): ByteArray? {
        return try {
            val icon = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                notification.getLargeIcon()
            } else {
                @Suppress("DEPRECATION")
                notification.extras.getParcelable(Notification.EXTRA_LARGE_ICON) as? android.graphics.drawable.Icon
            } ?: return null
            val bitmap = bitmapFromIcon(icon) ?: return null
            val scaled = if (bitmap.width > ART_MAX_PX || bitmap.height > ART_MAX_PX) {
                val ratio = min(
                    ART_MAX_PX.toFloat() / bitmap.width,
                    ART_MAX_PX.toFloat() / bitmap.height
                )
                Bitmap.createScaledBitmap(
                    bitmap,
                    (bitmap.width * ratio).roundToInt().coerceAtLeast(1),
                    (bitmap.height * ratio).roundToInt().coerceAtLeast(1),
                    true
                )
            } else {
                bitmap
            }
            ByteArrayOutputStream().use { out ->
                scaled.compress(Bitmap.CompressFormat.JPEG, 85, out)
                out.toByteArray()
            }
        } catch (_: Exception) {
            null
        }
    }

    /** Rasterizes an [android.graphics.drawable.Icon] (Icon.getBitmap is hidden in the SDK jar). */
    private fun bitmapFromIcon(icon: android.graphics.drawable.Icon): Bitmap? {
        return try {
            val drawable = icon.loadDrawable(this) ?: return null
            val width = drawable.intrinsicWidth.takeIf { it > 0 } ?: ART_MAX_PX
            val height = drawable.intrinsicHeight.takeIf { it > 0 } ?: ART_MAX_PX
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = android.graphics.Canvas(bitmap)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)
            bitmap
        } catch (_: Exception) {
            null
        }
    }

    private fun isMediaNotification(notification: Notification, extras: android.os.Bundle): Boolean {
        return extras.containsKey(Notification.EXTRA_MEDIA_SESSION) ||
                notification.category == Notification.CATEGORY_TRANSPORT ||
                notification.isMediaStyle()
    }

    private fun Notification.isMediaStyle(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
        val template = extras.getString(Notification.EXTRA_TEMPLATE)
        return template?.contains("MediaStyle") == true
    }
}

package com.fluee.fluee_launcher

import android.app.Notification
import android.media.session.MediaSession
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/**
 * Service allowing Fluee Launcher to read active media sessions
 * and fallback to active media notifications when Notification Access is granted.
 */
class LauncherNotificationListener : NotificationListenerService() {

    companion object {
        @Volatile
        var isConnected: Boolean = false
            private set

        @Volatile
        var latestMediaNotification: MediaTrackInfo? = null
            private set

        data class MediaTrackInfo(
            val title: String,
            val artist: String,
            val packageName: String,
            val isPlaying: Boolean
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
        val isMediaNotification = extras.containsKey(Notification.EXTRA_MEDIA_SESSION) ||
                sbn.notification.category == Notification.CATEGORY_TRANSPORT ||
                sbn.notification.isMediaNotification()

        if (isMediaNotification) {
            val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()
            val artist = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
                ?: extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString()

            if (!title.isNullOrEmpty()) {
                latestMediaNotification = MediaTrackInfo(
                    title = title,
                    artist = artist ?: "",
                    packageName = sbn.packageName,
                    isPlaying = true
                )
            }
        }
    }

    private fun scanActiveMediaNotifications() {
        try {
            val active = activeNotifications ?: return
            for (sbn in active) {
                val extras = sbn.notification.extras ?: continue
                if (extras.containsKey(Notification.EXTRA_MEDIA_SESSION) ||
                    sbn.notification.category == Notification.CATEGORY_TRANSPORT ||
                    sbn.notification.isMediaNotification()
                ) {
                    val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()
                    val artist = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
                        ?: extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString()
                    if (!title.isNullOrEmpty()) {
                        latestMediaNotification = MediaTrackInfo(
                            title = title,
                            artist = artist ?: "",
                            packageName = sbn.packageName,
                            isPlaying = true
                        )
                        return
                    }
                }
            }
        } catch (_: Exception) {}
    }

    private fun Notification.isMediaNotification(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val style = extras.getString(Notification.EXTRA_TEMPLATE)
            style?.contains("MediaStyle") == true
        } else {
            false
        }
    }
}

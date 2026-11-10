package com.fluee.fluee_launcher

import android.service.notification.NotificationListenerService

/**
 * Service stub allowing Fluee Launcher to read active media sessions
 * from MediaSessionManager when Notification Access is granted by the user.
 */
class LauncherNotificationListener : NotificationListenerService()

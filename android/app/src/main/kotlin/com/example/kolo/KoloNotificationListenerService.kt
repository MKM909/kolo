package com.example.kolo

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

class KoloNotificationListenerService : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val text = sbn.notification.extras.getCharSequence("android.text")?.toString()
        Log.d("KoloNotification", "Notification from ${sbn.packageName}: ${text.orEmpty()}")
    }
}

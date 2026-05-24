package com.micah.kolo

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

class KoloNotificationListenerService : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val text = sbn.notification.extras.getCharSequence("android.text")?.toString()
        val title = sbn.notification.extras.getCharSequence("android.title")?.toString()
        KoloNativeEventQueue.enqueue(
            this,
            "notification_posted",
            mapOf(
                "packageName" to sbn.packageName,
                "title" to title.orEmpty(),
                "text" to text.orEmpty()
            )
        )
        Log.d("KoloNotification", "Notification from ${sbn.packageName}: ${text.orEmpty()}")
    }
}

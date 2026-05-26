package com.micah.kolo

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

class KoloNotificationListenerService : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val extras = sbn.notification.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val baseText = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString().orEmpty()
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString().orEmpty()
        val textLines = extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)
            ?.mapNotNull { it?.toString() }
            ?.filter { it.isNotBlank() }
            ?.joinToString(" ")
            .orEmpty()
        val combinedText = listOf(baseText, bigText, textLines)
            .filter { it.isNotBlank() }
            .distinct()
            .joinToString(" ")
        KoloNativeEventQueue.enqueue(
            this,
            "notification_posted",
            mapOf(
                "packageName" to sbn.packageName,
                "title" to title,
                "text" to combinedText,
                "bigText" to bigText,
                "textLines" to textLines
            )
        )
        KoloBackgroundStarter.nudge(this)
        Log.d("KoloNotification", "Notification from ${sbn.packageName}: $combinedText")
    }
}

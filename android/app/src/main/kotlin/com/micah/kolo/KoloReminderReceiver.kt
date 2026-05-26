package com.micah.kolo

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import org.json.JSONObject

class KoloReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        createChannel(context)
        val id = intent.getStringExtra("id").orEmpty()
        val title = intent.getStringExtra("title").orEmpty().ifBlank { "Kolo reminder" }
        val body = intent.getStringExtra("body").orEmpty().ifBlank {
            "Open Kolo to review this money reminder."
        }
        val notification = notification(context, title, body)
        val manager = context.getSystemService(NotificationManager::class.java)
        KoloNativeEventQueue.enqueue(context, "reminder", reminderPayload(intent))
        manager.notify(id.hashCode(), notification)
    }

    private fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "kolo_reminders",
                "Kolo reminders",
                NotificationManager.IMPORTANCE_DEFAULT
            )
            context.getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    private fun notification(context: Context, title: String, body: String): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, "kolo_reminders")
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        return builder
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(openKoloIntent(context))
            .setAutoCancel(true)
            .build()
    }

    private fun openKoloIntent(context: Context): PendingIntent {
        val intent = Intent(
            Intent.ACTION_VIEW,
            Uri.parse("kolo://app/ai?prompt=Show%20my%20Kolo%20reminders")
        ).apply {
            setPackage(context.packageName)
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE
            } else {
                0
            }
        return PendingIntent.getActivity(context, 44, intent, flags)
    }

    private fun reminderPayload(intent: Intent): Map<String, Any?> {
        val payload = intent.getStringExtra("payload").orEmpty()
        val payloadJson = try {
            if (payload.isBlank()) JSONObject() else JSONObject(payload)
        } catch (_: Exception) {
            JSONObject()
        }
        return mapOf(
            "reminderId" to intent.getStringExtra("id").orEmpty(),
            "kind" to payloadJson.optString("kind")
        )
    }
}

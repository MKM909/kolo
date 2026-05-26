package com.micah.kolo

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONObject

object KoloReminderScheduler {
    fun schedule(context: Context, args: Map<Any?, Any?>) {
        val id = args["id"]?.toString() ?: return
        val scheduledAt = (args["scheduledAt"] as? Number)?.toLong() ?: return
        val intent = reminderIntent(context, id).apply {
            putExtra("id", id)
            putExtra("title", args["title"]?.toString().orEmpty())
            putExtra("body", args["body"]?.toString().orEmpty())
            putExtra("payload", JSONObject(args["payload"] as? Map<*, *> ?: emptyMap<Any?, Any?>()).toString())
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            id.hashCode(),
            intent,
            pendingIntentFlags()
        )
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        scheduleAlarm(alarmManager, scheduledAt, pendingIntent)
    }

    fun cancel(context: Context, id: String) {
        if (id.isEmpty()) return
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            id.hashCode(),
            reminderIntent(context, id),
            pendingIntentFlags()
        )
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(pendingIntent)
        pendingIntent.cancel()
    }

    private fun reminderIntent(context: Context, id: String): Intent {
        return Intent(context, KoloReminderReceiver::class.java).apply {
            action = "com.micah.kolo.REMINDER.$id"
        }
    }

    private fun scheduleAlarm(
        alarmManager: AlarmManager,
        scheduledAt: Long,
        pendingIntent: PendingIntent
    ) {
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            !alarmManager.canScheduleExactAlarms()
        ) {
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                scheduledAt,
                pendingIntent
            )
            return
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    scheduledAt,
                    pendingIntent
                )
            } else {
                @Suppress("DEPRECATION")
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, scheduledAt, pendingIntent)
            }
        } catch (securityException: SecurityException) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    scheduledAt,
                    pendingIntent
                )
            } else {
                alarmManager.set(AlarmManager.RTC_WAKEUP, scheduledAt, pendingIntent)
            }
        }
    }

    private fun pendingIntentFlags(): Int {
        return PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE
            } else {
                0
            }
    }
}

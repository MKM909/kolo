package com.micah.kolo

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class KoloBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            KoloNativeEventQueue.enqueue(
                context,
                "boot_completed",
                mapOf("action" to intent.action)
            )
            val serviceIntent = Intent(context, KoloForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        }
    }
}

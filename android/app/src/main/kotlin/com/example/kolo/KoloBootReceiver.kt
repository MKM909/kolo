package com.micah.kolo

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class KoloBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            KoloNativeEventQueue.enqueue(
                context,
                "boot_completed",
                mapOf("action" to intent.action)
            )
            KoloBackgroundStarter.nudge(context)
        }
    }
}

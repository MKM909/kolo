package com.micah.kolo

import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

object KoloBackgroundStarter {
    fun nudge(context: Context) {
        startNativeForegroundService(context)
        startFlutterBackgroundService(context)
    }

    fun startFlutterBackgroundService(context: Context) {
        startService(
            context,
            Intent(context, id.flutter.flutter_background_service.BackgroundService::class.java),
            "Flutter background service"
        )
    }

    private fun startNativeForegroundService(context: Context) {
        startService(
            context,
            Intent(context, KoloForegroundService::class.java),
            "Kolo foreground service"
        )
    }

    private fun startService(context: Context, intent: Intent, label: String) {
        val appContext = context.applicationContext
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                appContext.startForegroundService(intent)
            } else {
                @Suppress("DEPRECATION")
                appContext.startService(intent)
            }
        } catch (error: Exception) {
            Log.w("KoloBackgroundStarter", "Could not start $label", error)
        }
    }
}

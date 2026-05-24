package com.micah.kolo

import android.content.ComponentName
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "kolo/android_capabilities"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSuggestedBankingApps" -> result.success(getSuggestedBankingApps())
                "drainNativeEvents" -> result.success(KoloNativeEventQueue.drain(this))
                "openAccessibilitySettings" -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(true)
                }
                "openNotificationListenerSettings" -> {
                    startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                    result.success(true)
                }
                "isNotificationListenerEnabled" -> result.success(isNotificationListenerEnabled())
                else -> result.notImplemented()
            }
        }
    }

    private fun isNotificationListenerEnabled(): Boolean {
        val enabledListeners = Settings.Secure.getString(
            contentResolver,
            "enabled_notification_listeners"
        ) ?: return false
        val listenerComponent = ComponentName(
            this,
            KoloNotificationListenerService::class.java
        )
        val flattened = listenerComponent.flattenToString()
        val shortFlattened = listenerComponent.flattenToShortString()

        return enabledListeners.split(":").any { enabled ->
            enabled.equals(flattened, ignoreCase = true) ||
                enabled.equals(shortFlattened, ignoreCase = true)
        }
    }

    private fun getSuggestedBankingApps(): List<Map<String, Any>> {
        val packageManager = packageManager
        val knownApps = listOf(
            "com.kuda.android" to "Kuda",
            "team.opay.pay" to "Opay",
            "com.palmpay.android" to "Palmpay",
            "com.gtbank.gtworldv1" to "GTBank",
            "com.accessbank.accessmore" to "Access Bank",
            "com.moniepoint.personal" to "Moniepoint"
        )

        return knownApps.map { (packageName, displayName) ->
            val installed = runCatching {
                packageManager.getPackageInfo(packageName, 0)
            }.isSuccess
            mapOf(
                "packageName" to packageName,
                "displayName" to displayName,
                "enabled" to installed
            )
        }
    }
}

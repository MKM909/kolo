package com.micah.kolo

import android.content.ComponentName
import android.content.Intent
import android.os.Build
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
                "isAccessibilityServiceEnabled" -> result.success(isAccessibilityServiceEnabled())
                "isNotificationListenerEnabled" -> result.success(isNotificationListenerEnabled())
                "startBackgroundWatcher" -> result.success(startBackgroundWatcher())
                else -> result.notImplemented()
            }
        }
    }

    private fun startBackgroundWatcher(): Boolean {
        val serviceIntent = Intent(this, KoloForegroundService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            @Suppress("DEPRECATION")
            startService(serviceIntent)
        }
        return true
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        return isEnabledSecureComponent(
            "enabled_accessibility_services",
            ComponentName(this, KoloAccessibilityService::class.java)
        )
    }

    private fun isNotificationListenerEnabled(): Boolean {
        return isEnabledSecureComponent(
            "enabled_notification_listeners",
            ComponentName(this, KoloNotificationListenerService::class.java)
        )
    }

    private fun isEnabledSecureComponent(settingName: String, component: ComponentName): Boolean {
        val enabledComponents = Settings.Secure.getString(
            contentResolver,
            settingName
        ) ?: return false
        val flattened = component.flattenToString()
        val shortFlattened = component.flattenToShortString()

        return enabledComponents.split(":").any { enabled ->
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
            "com.moniepoint.personal" to "Moniepoint",
            "com.lenddo.mobile.paylater" to "Carbon",
            "ng.com.fairmoney.fairmoney" to "FairMoney"
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

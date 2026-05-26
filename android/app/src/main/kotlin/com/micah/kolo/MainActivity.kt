package com.micah.kolo

import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
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
                "getInstalledAppCandidates" -> result.success(getInstalledAppCandidates())
                "getSuggestedBankingApps" -> result.success(getSuggestedBankingApps())
                "enqueueNativeEvent" -> {
                    @Suppress("UNCHECKED_CAST")
                    KoloNativeEventQueue.append(this, call.arguments as? Map<Any?, Any?> ?: emptyMap())
                    result.success(null)
                }
                "peekNativeEvents" -> result.success(KoloNativeEventQueue.peek(this))
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
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "kolo/reminders"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleReminder" -> {
                    @Suppress("UNCHECKED_CAST")
                    KoloReminderScheduler.schedule(this, call.arguments as? Map<Any?, Any?> ?: emptyMap())
                    result.success(null)
                }
                "cancelReminder" -> {
                    @Suppress("UNCHECKED_CAST")
                    val args = call.arguments as? Map<Any?, Any?> ?: emptyMap()
                    KoloReminderScheduler.cancel(this, args["id"]?.toString().orEmpty())
                    result.success(null)
                }
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
        return getInstalledAppCandidates()
            .filter { it["isKnownFinancialApp"] as? Boolean ?: false }
            .map { candidate ->
                mapOf(
                    "packageName" to candidate["packageName"].toString(),
                    "displayName" to candidate["displayName"].toString(),
                    "enabled" to (candidate["installed"] as? Boolean ?: false)
                )
            }
    }

    private fun getInstalledAppCandidates(): List<Map<String, Any>> {
        val knownApps = mapOf(
            "com.kuda.android" to "Kuda",
            "team.opay.pay" to "Opay",
            "com.palmpay.android" to "Palmpay",
            "com.gtbank.gtworldv1" to "GTBank",
            "com.accessbank.accessmore" to "Access Bank",
            "com.moniepoint.personal" to "Moniepoint",
            "com.lenddo.mobile.paylater" to "Carbon",
            "ng.com.fairmoney.fairmoney" to "FairMoney"
        )

        val candidates = linkedMapOf<String, Map<String, Any>>()
        val launcherIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        val launchableApps = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.queryIntentActivities(
                launcherIntent,
                PackageManager.ResolveInfoFlags.of(0)
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.queryIntentActivities(launcherIntent, 0)
        }

        for (resolveInfo in launchableApps) {
            val packageName = resolveInfo.activityInfo?.packageName ?: continue
            val label = resolveInfo.loadLabel(packageManager)?.toString()
                ?.takeIf { it.isNotBlank() }
                ?: knownApps[packageName]
                ?: packageName
            val isKnownFinancialApp = knownApps.containsKey(packageName)
            candidates[packageName] = mapOf(
                "packageName" to packageName,
                "displayName" to (knownApps[packageName] ?: label),
                "installed" to true,
                "isKnownFinancialApp" to isKnownFinancialApp
            )
        }

        for ((packageName, displayName) in knownApps) {
            if (candidates.containsKey(packageName)) continue
            candidates[packageName] = mapOf(
                "packageName" to packageName,
                "displayName" to displayName,
                "installed" to isPackageInstalled(packageName),
                "isKnownFinancialApp" to true
            )
        }

        return candidates.values.sortedWith(
            compareBy<Map<String, Any>> { candidateRank(it) }
                .thenBy { it["displayName"].toString().lowercase() }
        )
    }

    private fun candidateRank(candidate: Map<String, Any>): Int {
        val installed = candidate["installed"] as? Boolean ?: false
        val knownFinancial = candidate["isKnownFinancialApp"] as? Boolean ?: false
        return when {
            knownFinancial && installed -> 0
            knownFinancial -> 1
            installed -> 2
            else -> 3
        }
    }

    private fun isPackageInstalled(packageName: String): Boolean {
        return runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getPackageInfo(
                    packageName,
                    PackageManager.PackageInfoFlags.of(0)
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(packageName, 0)
            }
        }.isSuccess
    }
}

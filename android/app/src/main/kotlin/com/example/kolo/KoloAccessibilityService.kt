package com.micah.kolo

import android.accessibilityservice.AccessibilityService
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import java.lang.ref.WeakReference

class KoloAccessibilityService : AccessibilityService() {
    override fun onServiceConnected() {
        currentService = WeakReference(this)
        Log.d("KoloAccessibility", "Accessibility service connected")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            KoloNativeEventQueue.enqueue(
                this,
                "foreground_app",
                mapOf("packageName" to event.packageName?.toString().orEmpty())
            )
            Log.d("KoloAccessibility", "Foreground app changed: ${event.packageName}")
        }
    }

    override fun onInterrupt() {
        Log.d("KoloAccessibility", "Accessibility service interrupted")
    }

    override fun onDestroy() {
        if (currentService?.get() == this) {
            currentService = null
        }
        super.onDestroy()
    }

    companion object {
        private var currentService: WeakReference<KoloAccessibilityService>? = null

        fun performGlobalBackAction(): Boolean {
            val service = currentService?.get() ?: return false
            return service.performGlobalAction(GLOBAL_ACTION_BACK)
        }
    }
}

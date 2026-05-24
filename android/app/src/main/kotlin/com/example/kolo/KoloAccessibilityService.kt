package com.micah.kolo

import android.accessibilityservice.AccessibilityService
import android.util.Log
import android.view.accessibility.AccessibilityEvent

class KoloAccessibilityService : AccessibilityService() {
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            Log.d("KoloAccessibility", "Foreground app changed: ${event.packageName}")
        }
    }

    override fun onInterrupt() {
        Log.d("KoloAccessibility", "Accessibility service interrupted")
    }
}

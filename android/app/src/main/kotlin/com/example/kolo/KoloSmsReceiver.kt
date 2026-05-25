package com.micah.kolo

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.util.Log

class KoloSmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            val body = messages.joinToString(separator = "") { it.messageBody.orEmpty() }
            val sender = messages.firstOrNull()?.displayOriginatingAddress.orEmpty()
            KoloNativeEventQueue.enqueue(
                context,
                "sms_received",
                mapOf(
                    "body" to body,
                    "sender" to sender
                )
            )
            Log.d("KoloSmsReceiver", "SMS received for parsing: $body")
        }
    }
}

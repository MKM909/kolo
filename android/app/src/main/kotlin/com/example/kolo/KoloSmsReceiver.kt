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
            Log.d("KoloSmsReceiver", "SMS received for parsing: $body")
        }
    }
}

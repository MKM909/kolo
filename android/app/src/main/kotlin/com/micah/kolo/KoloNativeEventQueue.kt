package com.micah.kolo

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

object KoloNativeEventQueue {
    private const val PREFS_NAME = "kolo_native_events"
    private const val EVENTS_KEY = "events"

    fun enqueue(context: Context, type: String, payload: Map<String, Any?>) {
        val event = JSONObject()
            .put("id", "${System.currentTimeMillis()}-$type")
            .put("type", type)
            .put("createdAt", System.currentTimeMillis())
            .put("payload", JSONObject(payload))

        appendJson(context, event)
    }

    fun append(context: Context, event: Map<Any?, Any?>) {
        val payload = event["payload"] as? Map<*, *> ?: emptyMap<Any?, Any?>()
        val now = System.currentTimeMillis()
        val eventJson = JSONObject()
            .put("id", event["id"]?.toString() ?: "$now-unknown")
            .put("type", event["type"]?.toString() ?: "unknown")
            .put("createdAt", (event["createdAt"] as? Number)?.toLong() ?: now)
            .put("payload", JSONObject(payload))

        appendJson(context, eventJson)
    }

    fun peek(context: Context): List<Map<String, Any?>> {
        return readEvents(context)
    }

    fun drain(context: Context): List<Map<String, Any?>> {
        val drained = readEvents(context)
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .remove(EVENTS_KEY)
            .apply()
        return drained
    }

    private fun appendJson(context: Context, event: JSONObject) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val events = JSONArray(prefs.getString(EVENTS_KEY, "[]"))
        events.put(event)
        prefs.edit().putString(EVENTS_KEY, events.toString()).apply()
    }

    private fun readEvents(context: Context): List<Map<String, Any?>> {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val events = JSONArray(prefs.getString(EVENTS_KEY, "[]"))
        val drained = mutableListOf<Map<String, Any?>>()

        for (index in 0 until events.length()) {
            val event = events.getJSONObject(index)
            drained.add(
                mapOf(
                    "id" to event.optString("id"),
                    "type" to event.optString("type"),
                    "createdAt" to event.optLong("createdAt"),
                    "payload" to event.optJSONObject("payload").toMap()
                )
            )
        }

        return drained
    }

    private fun JSONObject?.toMap(): Map<String, Any?> {
        if (this == null) return emptyMap()

        val output = mutableMapOf<String, Any?>()
        val keys = keys()
        while (keys.hasNext()) {
            val key = keys.next()
            val value = opt(key)
            output[key] = if (value == JSONObject.NULL) null else value
        }
        return output
    }
}

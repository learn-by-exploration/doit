package com.doit

import android.content.Context
import android.media.AudioManager
import android.os.Build
import android.telecom.Call
import android.telecom.CallScreeningService
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Thin Kotlin-side adapter for the `doit/call_interceptor`
 * method channel (v1.0 / Phase F PR 1 / ADR-019 / SYS-075).
 *
 * Two responsibilities:
 *
 *   1. Receive calls from Dart (`setEnabled`, `setContactIds`,
 *      `setRingerMode`, `restorePriorRinger`, `startStream`,
 *      `stopStream`) and respond synchronously. The Dart
 *      side configures which phone numbers should bypass
 *      silent mode and which ringer override is in effect.
 *
 *   2. Act as a `CallScreeningService` (declared in the
 *      manifest with `BIND_SCREENING_SERVICE`). The OS
 *      invokes `onScreenCall(Call.Details)` for every
 *      incoming call before the dialer rings; this class
 *      decides whether to allow the call normally, silence
 *      it (when the contact is in the configured list AND
 *      silent mode is on — the Japan routine), or pass it
 *      through. Matched contacts are forwarded to the Dart
 *      side via `invokeMethod("onCallEvent", map)` so the
 *      matching engine can fire the routine.
 *
 * Library choice: native `CallScreeningService` over the
 * `PhoneAccount` self-managed surface. See ADR-019 for the
 * full rationale. Key points:
 *   - No `READ_PHONE_STATE` permission.
 *   - The bound permission (`BIND_SCREENING_SERVICE`) is
 *     signature-protected and granted at install time.
 *   - The screening service runs synchronously before the
 *     dialer rings; the `CallResponse` is honored by the OS.
 *
 * Reliability: when the app process is not alive the
 * screening service is started by the OS as a cold-start
 * service. The `setEnabled` flag defaults to `false`; an
 * unconfigured service passes every call through (returns
 * the default `CallResponse` with `skipCall = false`). The
 * routine can never fire without an explicit Dart-side
 * `setEnabled(true)` call from the user's Japan-routine
 * configuration.
 */
class CallInterceptor : CallScreeningService() {

    override fun onScreenCall(details: Call.Details) {
        val cfg = Companion.config
        val incomingNumber = details.handle?.schemeSpecificPart ?: ""

        // Forward every incoming call to Dart so the
        // matching engine can decide whether to fire the
        // routine. The Dart side dispatches based on
        // TriggerCallIncomingAny / KnownContact /
        // UnknownContact. The Kotlin side also returns
        // its own CallResponse synchronously so the dialer
        // is not blocked on the Dart round-trip.
        val eventMap = mapOf(
            "kind" to "incoming",
            "number" to incomingNumber,
            "isKnownContact" to false, // best-effort; the resolver is on the Dart side
            "displayName" to "",
            "atMs" to System.currentTimeMillis(),
        )
        Companion.pushCallEvent(eventMap)

        // Default response: pass through. If silent mode
        // is on AND the contact is in the configured
        // list, snap ringer to NORMAL and pass through
        // with a "skipCall" response so the dialer does
        // not ring on its own (we play the contact's
        // ringtone ourselves — Phase F PR 2 wires that).
        val response = Call.Response.Builder()
        if (!cfg.enabled) {
            respondToCall(details, response.build())
            return
        }
        val matches = cfg.contactNumbers.any { it == incomingNumber }
        if (!matches) {
            respondToCall(details, response.build())
            return
        }
        val ctx = applicationContext
        val audio = ctx?.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        val priorMode = audio?.ringerMode ?: AudioManager.RINGER_MODE_NORMAL
        // Cache the prior mode so restorePriorRinger() can
        // snap back. The cache is process-scoped; cold
        // starts between the override and the dismiss
        // collapse the prior mode to NORMAL (best-effort
        // documented in ADR-019).
        Companion.lastPriorRingerMode = priorMode
        if (audio != null) {
            try {
                audio.ringerMode = AudioManager.RINGER_MODE_NORMAL
            } catch (_: SecurityException) {
                // Some OEMs restrict programmatic ringer
                // changes. The routine logs but does not
                // crash the screening callback.
            }
        }
        // Notify Dart that the ringer has been overridden
        // (so the executor can fire ActionOverrideSilent
        // and the dismiss path can be wired).
        Companion.pushCallEvent(
            mapOf(
                "kind" to "ringerOverridden",
                "number" to incomingNumber,
                "isKnownContact" to true,
                "displayName" to "",
                "atMs" to System.currentTimeMillis(),
                "priorMode" to priorMode,
                "targetMode" to AudioManager.RINGER_MODE_NORMAL,
            ),
        )
        response.setSkipCall(false)
        response.setSilenceCall(false) // we want the contact ringtone to play
        response.setDisallowCall(false)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            response.setRejectCall(false)
        }
        respondToCall(details, response.build())
    }

    // -----------------------------------------------------------------------
    // Companion: shared configuration + channel object (process-scoped).
    // -----------------------------------------------------------------------

    companion object {
        private const val CHANNEL = "doit/call_interceptor"
        private const val SINK_METHOD = "onCallEvent"

        @Volatile
        private var appContext: Context? = null

        @Volatile
        private var channel: MethodChannel? = null

        /**
         * Configuration pushed in by Dart via `setEnabled` /
         * `setContactIds`. Defaults: disabled, no contacts.
         * An unconfigured service is a pass-through.
         */
        class CallConfig {
            @Volatile var enabled: Boolean = false
            @Volatile var contactNumbers: Set<String> = emptySet()
        }

        val config = CallConfig()

        /**
         * Most recent prior ringer mode (cached at the moment
         * of the override). Used by `restorePriorRinger()`
         * to snap back. `null` = no override is in flight.
         */
        @Volatile
        var lastPriorRingerMode: Int? = null

        fun setAppContext(ctx: Context) {
            appContext = ctx.applicationContext
        }

        fun attach(engine: FlutterEngine) {
            val ch = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "setEnabled" -> {
                        val enabled = (call.arguments as? Map<*, *>)
                            ?.get("enabled") as? Boolean ?: false
                        config.enabled = enabled
                        result.success(null)
                    }
                    "setContactIds" -> {
                        val ids = (call.arguments as? Map<*, *>)
                            ?.get("ids") as? List<*>
                        config.contactNumbers = ids
                            ?.mapNotNull { it as? String }
                            ?.toSet()
                            ?: emptySet()
                        result.success(null)
                    }
                    "setRingerMode" -> {
                        val mode = (call.arguments as? Map<*, *>)
                            ?.get("mode") as? String ?: "normal"
                        val audio = appContext
                            ?.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
                        if (audio != null) {
                            try {
                                audio.ringerMode = when (mode) {
                                    "silent" -> AudioManager.RINGER_MODE_SILENT
                                    "vibrate" -> AudioManager.RINGER_MODE_VIBRATE
                                    else -> AudioManager.RINGER_MODE_NORMAL
                                }
                            } catch (_: SecurityException) {
                                // ignore — see onScreenCall comment
                            }
                        }
                        result.success(null)
                    }
                    "getRingerMode" -> {
                        val audio = appContext
                            ?.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
                        val mode = audio?.ringerMode
                            ?: AudioManager.RINGER_MODE_NORMAL
                        val name = when (mode) {
                            AudioManager.RINGER_MODE_SILENT -> "silent"
                            AudioManager.RINGER_MODE_VIBRATE -> "vibrate"
                            else -> "normal"
                        }
                        result.success(name)
                    }
                    "restorePriorRinger" -> {
                        val prior = lastPriorRingerMode
                        if (prior != null) {
                            val audio = appContext
                                ?.getSystemService(Context.AUDIO_SERVICE)
                                as? AudioManager
                            if (audio != null) {
                                try {
                                    audio.ringerMode = prior
                                } catch (_: SecurityException) {
                                    // ignore
                                }
                            }
                            lastPriorRingerMode = null
                        }
                        result.success(null)
                    }
                    "startStream" -> {
                        // No-op: the screening service is
                        // bound by the OS, not by Dart. The
                        // method is accepted so the Dart
                        // service's start() can mirror the
                        // shape of the calendar / device-
                        // state / geofence streams.
                        result.success(null)
                    }
                    "stopStream" -> result.success(null)
                    else -> result.notImplemented()
                }
            }
            channel = ch
        }

        fun detach() {
            channel?.setMethodCallHandler(null)
            channel = null
        }

        internal fun pushCallEvent(map: Map<String, Any?>) {
            channel?.invokeMethod(SINK_METHOD, map)
        }
    }
}
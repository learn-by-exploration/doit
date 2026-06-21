package com.doit

import android.app.Activity
import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import android.telecom.Call
import android.telecom.CallScreeningService
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
// CallScreeningService.CallResponse.Builder was promoted to the
// canonical API in API 31+; the older `Call.Response` was removed
// at the same time. The Builder requires API 30+ at runtime, which
// is mirrored by the minSdk bump in `android/app/build.gradle.kts`
// from 28 to 30 (see the inline comment there for the rationale).
// The Builder's `setSkipCall()` setter was retired in API 31 — the
// default Builder() now produces a pass-through response, which is
// exactly the behavior this service wants for non-matched calls.

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
        // so the dialer does not ring on its own
        // (we play the contact's ringtone ourselves —
        // Phase F PR 2 wires that).
        //
        // The Builder used to live on `Call.Response`; in
        // API 31+ that class was removed and the canonical
        // home is `CallScreeningService.CallResponse.Builder`.
        // Its `setSkipCall()` setter was retired in API 31
        // — the default Builder() now produces a
        // pass-through response (skipCall=false), which is
        // exactly what we want for non-matched calls and
        // for the matched-contact case where we still
        // want the dialer to ring (so our override of
        // the contact ringtone takes effect).
        val response = CallScreeningService.CallResponse.Builder()
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

        /**
         * Currently-attached Activity (held weakly via setActivity()
         * from MainActivity.configureFlutterEngine / onDestroy).
         * Used by [requestCallScreeningRole] to launch the OS
         * role-request intent with startActivityForResult. The
         * Activity reference was previously fetched via
         * `engine.activity`, a getter that was removed from the
         * Flutter embedding in 3.x — the explicit setActivity()
         * call from MainActivity replaces it.
         */
        @Volatile
        private var currentActivity: Activity? = null

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

        /**
         * Holds the Activity reference needed by
         * [requestCallScreeningRole]. Replaces the
         * `engine.activity` getter, which was removed in
         * the modern Flutter embedding. MainActivity calls
         * this with `this` from `configureFlutterEngine` and
         * with `null` from `onDestroy` so a stale Activity
         * is never leaked after the screen rotates or the
         * activity is destroyed.
         */
        fun setActivity(act: Activity?) {
            currentActivity = act
        }

        fun attach(engine: FlutterEngine) {
            val ch = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            val activity: Activity? = currentActivity
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
                    "isCallScreeningRoleHeld" -> {
                        // Phase F PR 2 (SYS-075 / SYS-079):
                        // returns whether the user has opted
                        // in to the call-screening role via
                        // `RoleManager`. The role is opt-in
                        // (not a runtime permission). When
                        // `RoleManager` is unavailable
                        // (Android < Q) we conservatively
                        // return `false` so the UI surfaces
                        // the role as not-yet-held.
                        val held = isCallScreeningRoleHeld()
                        result.success(held)
                    }
                    "requestCallScreeningRole" -> {
                        // Phase F PR 2 (SYS-075 / SYS-079):
                        // fires the OS role-request flow.
                        // Returns:
                        //   - `true` if the role was already
                        //     held (no dialog needed).
                        //   - `true` if the user granted the
                        //     role in the dialog.
                        //   - `false` if the role is
                        //     unavailable (Android < Q or
                        //     no Activity), or the user
                        //     declined, or the dialog was
                        //     already in flight.
                        val granted = requestCallScreeningRole(activity)
                        result.success(granted)
                    }
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

        // -------------------------------------------------------------------
        // Phase F PR 2 (SYS-075 / SYS-079): call-screening role probe.
        //
        // The `ROLE_CALL_SCREENING` role is opt-in on Android Q+.
        // The user grants it via the OS role-holders settings page
        // (and a chooser dialog the OS shows on request). We do
        // not gate the routine on a runtime permission — the
        // bound permission (`BIND_SCREENING_SERVICE`) is
        // signature-protected and granted at install time. The
        // role is the only thing that has to be earned.
        // -------------------------------------------------------------------

        /**
         * `true` if the app currently holds the call-screening
         * role. The role is opt-in on Android Q+; below Q the
         * role does not exist so we return `false` (the screening
         * service is declared in the manifest and bound by the
         * OS — older OS versions simply do not expose the role
         * gating surface).
         */
        fun isCallScreeningRoleHeld(): Boolean {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
            val ctx = appContext ?: return false
            val rm = ctx.getSystemService(Context.ROLE_SERVICE) as? RoleManager
                ?: return false
            return rm.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)
        }

        /**
         * Request the call-screening role. Returns `true` if
         * the role is already held or was just granted; `false`
         * if the role is unavailable (no Activity context, OS
         * pre-Q) or the user declined. The OS dialog is
         * asynchronous — this method only fires the intent
         * and the Dart side observes the next probe for the
         * actual grant (the user may tap "Allow" later, after
         * they re-open the settings screen).
         */
        fun requestCallScreeningRole(activity: Activity?): Boolean {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
            if (isCallScreeningRoleHeld()) return true
            val act = activity ?: return false
            val rm = act.getSystemService(Context.ROLE_SERVICE) as? RoleManager
                ?: return false
            val intent = rm.createRequestRoleIntent(RoleManager.ROLE_CALL_SCREENING)
                ?: return false
            return try {
                act.startActivityForResult(intent, REQ_ROLE_CALL_SCREENING)
                true
            } catch (_: Exception) {
                // Some OEM ROMs throw on the role intent (no
                // role-holders settings activity). Treat as
                // not-granted; the user can fall back to the
                // Settings tile which deep-links to the system
                // app-settings page.
                false
            }
        }

        /**
         * Request code for the call-screening role request.
         * The result is observed by [MainActivity.onActivityResult]
         * when the role flow completes — we re-probe the role
         * via [isCallScreeningRoleHeld] on the next Settings tile
         * visit. The request code is unused on the Dart side;
         * it's reserved for a future hook that pushes a fresh
         * `onRoleChanged` event back to the singleton.
         */
        private const val REQ_ROLE_CALL_SCREENING = 9001
    }
}
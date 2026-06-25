package com.doit

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Thin Kotlin-side adapter for the `doit/full_screen` method
 * channel (v1.3c / Phase 14 / SYS-113 / ADR-043).
 *
 * Responsibilities:
 *   - Receive `canUseFullScreenIntent` calls from Dart and
 *     respond with a `Boolean`. The probe is purely a read;
 *     it does not ask the user for the permission (Android
 *     never shows a runtime prompt for `USE_FULL_SCREEN_INTENT`
 *     — the user must toggle it manually in Settings).
 *   - Receive `openFullScreenIntentSettings` calls and
 *     launch the corresponding Settings activity. Returns
 *     `true` if the launch resolved, `false` otherwise.
 *
 * API asymmetry (Android's gradual rollout of the FSI
 * permission):
 *
 *   - API < 32: Full-screen intents are implicitly granted
 *     to every app. The probe returns `true`; there is no
 *     Settings activity to deep-link to (the user did not
 *     need to opt in). The deep-link falls back to
 *     `ACTION_APPLICATION_SETTINGS`.
 *   - API 32 / 33 (`S_V2` / `TIRAMISU`): the probe reads
 *     `NotificationManager.canUseFullScreenIntent()`.
 *     Android does NOT expose a dedicated Settings activity
 *     for the permission on these API levels — the deep-link
 *     falls back to `ACTION_APPLICATION_SETTINGS` (the
 *     catch-all app-info page, which lists every toggle for
 *     the app, including "Appear on top" / full-screen
 *     intents on OEM builds that surface it).
 *   - API 34+ (`UPSIDE_DOWN_CAKE`): the probe reads
 *     `NotificationManager.canUseFullScreenIntent()`; the
 *     deep-link uses
 *     `Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT`
 *     which lands the user directly on the FSI toggle.
 *
 * The Dart side (`FullScreenIntentService`) is platform-
 * agnostic — the Kotlin handler resolves the right API
 * branch. The Dart `_safe` wrapper is unchanged for the
 * launch-method calls (`showHabitMission`,
 * `showRoutineOverlay`); Phase 6a proper will fill those
 * in via the same channel.
 */
object FullScreenIntentChannel {
    private const val CHANNEL = "doit/full_screen"

    private var channel: MethodChannel? = null

    fun attach(engine: FlutterEngine) {
        val ch = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "canUseFullScreenIntent" -> {
                    val ctx = appContext
                    if (ctx == null) {
                        result.error(
                            "NO_CONTEXT",
                            "FullScreenIntentChannel has no app context",
                            null,
                        )
                    } else {
                        result.success(canUseFullScreenIntent(ctx))
                    }
                }
                "openFullScreenIntentSettings" -> {
                    val ctx = appContext
                    if (ctx == null) {
                        result.error(
                            "NO_CONTEXT",
                            "FullScreenIntentChannel has no app context",
                            null,
                        )
                    } else {
                        val launched = openFullScreenIntentSettings(ctx)
                        result.success(launched)
                    }
                }
                else -> result.notImplemented()
            }
        }
        channel = ch
    }

    /** Public so MainActivity can call it. */
    fun detach() {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    @Volatile
    private var appContext: Context? = null

    fun setAppContext(ctx: Context) {
        appContext = ctx.applicationContext
    }

    /**
     * Returns true if the user has granted do it the
     * `USE_FULL_SCREEN_INTENT` permission.
     *
     * API < 32: the permission is implicit — every app may
     * launch full-screen intents. Return `true` so the Dart
     * derive rule stays optimal.
     *
     * API 32+: `NotificationManager.canUseFullScreenIntent()`
     * reads the user's toggle in system Settings. The
     * runtime `Context.getSystemService(NOTIFICATION_SERVICE)`
     * is safe on every API level (the class is API 1+).
     */
    private fun canUseFullScreenIntent(ctx: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S_V2) {
            return true
        }
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE)
            as? NotificationManager ?: return false
        return runCatching { nm.canUseFullScreenIntent() }.getOrDefault(false)
    }

    /**
     * Deep-links the user to the Settings page for the FSI
     * permission. Returns true if the launch resolved;
     * false if no activity handled the intent.
     *
     * API < 34: there is no dedicated FSI Settings activity.
     * Falls back to `ACTION_APPLICATION_SETTINGS` (the app-
     * info page) — OEMs that surface a per-app FSI toggle on
     * these API levels route the user to it from there.
     *
     * API 34+: `Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT`
     * lands the user directly on the FSI toggle.
     */
    private fun openFullScreenIntentSettings(ctx: Context): Boolean {
        val action = if (Build.VERSION.SDK_INT >=
                Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT
        } else {
            Settings.ACTION_APPLICATION_SETTINGS
        }
        val intent = Intent(action).apply {
            // `ACTION_APPLICATION_SETTINGS` resolves via the
            // app-info activity (no extra data needed). The
            // FSI-specific action requires the package name as
            // the data URI; Android's intent resolver parses it
            // from the calling package on the user's behalf.
            if (action == Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT) {
                data = android.net.Uri.fromParts("package", ctx.packageName, null)
            }
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return runCatching {
            ctx.startActivity(intent)
            true
        }.getOrDefault(false)
    }
}
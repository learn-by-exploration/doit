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
 * channel (v1.3c / Phase 14 / SYS-113 / ADR-043 + v1.3d /
 * Phase 15 / SYS-114 / ADR-044).
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
 *   - Receive `showHabitMission` calls (v1.3d / SYS-114)
 *     and launch `FullScreenActivity` for the given
 *     `habitId`. Returns `true` if the launch resolved,
 *     `false` otherwise.
 *   - Receive `showRoutineOverlay` calls (v1.3d / SYS-114)
 *     and launch `FullScreenActivity` in routine-overlay
 *     mode with the given `title` / `body`. Returns
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
 * branch. v1.3d / SYS-114 / ADR-044 fills in the launch
 * handlers (`showHabitMission`, `showRoutineOverlay`) on
 * the same channel; the Dart `_safe` wrapper is unchanged
 * (defense-in-depth per ADR-013).
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
                "showHabitMission" -> {
                    // v1.3d / SYS-114 / ADR-044: launch
                    // `FullScreenActivity` in habit mode.
                    // The Dart side passes `{habitId: "..."}`
                    // as the method arguments.
                    val ctx = appContext
                    if (ctx == null) {
                        result.error(
                            "NO_CONTEXT",
                            "FullScreenIntentChannel has no app context",
                            null,
                        )
                    } else {
                        val args = call.arguments as? Map<*, *>
                        val habitId =
                            args?.get("habitId") as? String
                        if (habitId.isNullOrEmpty()) {
                            result.error(
                                "BAD_ARGS",
                                "showHabitMission requires non-empty habitId",
                                null,
                            )
                        } else {
                            val launched = showHabitMission(ctx, habitId)
                            result.success(launched)
                        }
                    }
                }
                "showRoutineOverlay" -> {
                    // v1.3d / SYS-114 / ADR-044: launch
                    // `FullScreenActivity` in routine-
                    // overlay mode with optional title /
                    // body. The Dart side passes
                    // `{title: "...", body: "..."}` (both
                    // optional) as the method arguments.
                    val ctx = appContext
                    if (ctx == null) {
                        result.error(
                            "NO_CONTEXT",
                            "FullScreenIntentChannel has no app context",
                            null,
                        )
                    } else {
                        val args = call.arguments as? Map<*, *>
                        val title = args?.get("title") as? String
                        val body = args?.get("body") as? String
                        val launched = showRoutineOverlay(ctx, title, body)
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

    /**
     * v1.3d / Phase 15 / SYS-114 / ADR-044. Launch the
     * `FullScreenActivity` in habit mode for the given
     * `habitId`. The activity's `getInitialRoute()` reads
     * the `habitId` extra and encodes it into the
     * `/mission?mode=habit&habitId=...` route that the
     * Dart `MissionLauncherScreen` parses.
     *
     * Returns `true` if the launch resolved; `false` if
     * the OS refused the launch (e.g., no `USE_FULL_SCREEN_INTENT`
     * permission on API 34+). The Dart side logs the
     * failure under `kDebugMode` per ADR-013.
     */
    private fun showHabitMission(ctx: Context, habitId: String): Boolean {
        val intent = FullScreenActivity.habitIntent(ctx, habitId)
        return runCatching {
            ctx.startActivity(intent)
            true
        }.getOrDefault(false)
    }

    /**
     * v1.3d / Phase 15 / SYS-114 / ADR-044. Launch the
     * `FullScreenActivity` in routine-overlay mode with
     * the given (optional) `title` / `body`. The
     * activity's `getInitialRoute()` encodes them into
     * the `/mission?mode=overlay&title=...&body=...`
     * route that the Dart `RoutineOverlayScreen`
     * parses.
     */
    private fun showRoutineOverlay(
        ctx: Context,
        title: String?,
        body: String?,
    ): Boolean {
        val intent = FullScreenActivity.overlayIntent(ctx, title, body)
        return runCatching {
            ctx.startActivity(intent)
            true
        }.getOrDefault(false)
    }
}
package com.doit

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * Thin Kotlin shell that hosts a Flutter route to `/mission`.
 *
 * v1.3d / Phase 6a proper / Phase 15 / SYS-114 / ADR-044:
 * closes the launch path that Phase 14 (v1.3c / SYS-113 /
 * ADR-043) explicitly deferred. The v1.3c PR shipped the
 * `doit/full_screen` channel probe + deep-link handlers
 * (`canUseFullScreenIntent`, `openFullScreenIntentSettings`)
 * but left `showHabitMission` and `showRoutineOverlay`
 * returning `notImplemented`. This activity is the
 * destination those launch handlers now build an Intent
 * for.
 *
 * Why a separate activity (NOT a new `launchMode` on
 * `MainActivity`):
 *
 *   - Distinct task affinity (`taskAffinity=""`) so the
 *     full-screen launch does NOT pollute `MainActivity`'s
 *     back-stack — when the user closes the mission UI,
 *     they return to the home screen (or the lockscreen,
 *     or wherever the system routed them from), not to a
 *     `MainActivity` re-entry they did not ask for.
 *
 *   - Distinct theme / launchMode / keyguard-bypass flags
 *     per `docs/v_model/notification_reliability.md` §
 *     Layer 1. `MainActivity`'s flags would have to be
 *     conditionally set on every launch (strong-mode path
 *     vs normal launch path); a separate activity makes
 *     the strong-mode behavior the default for this
 *     class.
 *
 *   - The activity is excluded from recents so a missed
 *     full-screen launch does not show up in the
 *     app-switcher as a phantom entry.
 *
 * Window flags (`FLAG_SHOW_WHEN_LOCKED |
 * FLAG_TURN_SCREEN_ON | FLAG_DISMISS_KEYGUARD |
 * FLAG_KEEP_SCREEN_ON`) implement the strong-mode
 * interruption contract: the OS surfaces this activity on
 * top of the keyguard so the user sees the mission UI
 * immediately on alarm fire. `FLAG_KEEP_SCREEN_ON`
 * replaces the v1.2e `wakelock_plus` design — the lock is
 * held at the Window level and released automatically when
 * the activity is destroyed (no per-mission lifecycle
 * to track).
 *
 * Channel wiring (intentional non-action):
 *
 *   This activity's `configureFlutterEngine` does NOT
 *   attach the Kotlin channels that `MainActivity` owns.
 *   `MainActivity`'s engine is the live one for the
 *   process; a separately-launched `FlutterActivity`
 *   creates a fresh engine whose channels are
 *   unconfigured. Resolution: the launcher's Dart side
 *   does not need channels — it reads the habit by id
 *   from `DoRepository.instance.getById(...)` (pure Drift
 *   read, no platform-channel dependency), iterates the
 *   mission chain (pure Dart), and renders widgets. A
 *   future Phase that adds a channel-backed call to the
 *   launcher (e.g., vibrate-on-completion) must attach
 *   the relevant channel here, mirroring `MainActivity`.
 *
 * Initial route encoding:
 *
 *   `getInitialRoute()` reads the activity's launching
 *   intent and encodes the extras (`mode`, `habitId`,
 *   `title`, `body`) as a query string on the route
 *   `/mission?...`. The Dart side parses the route with
 *   `RouteSettings.arguments` (a `Map<String, Object?>`).
 *   Encoding the route as a query string (NOT as
 *   `RouteSettings.arguments`) lets the Flutter embedding
 *   hand the route to `MaterialApp.onGenerateRoute` on
 *   the first frame — the same path the embedding uses
 *   for a non-null `initialRoute`. The Dart side does
 *   not need a method-channel round-trip to discover
 *   what it should render.
 */
class FullScreenActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Keyguard bypass for the strong-mode interruption
        // contract (SYS-114). These flags mirror the
        // v1.2e FullScreenActivity design comment but with
        // `FLAG_DISMISS_KEYGUARD` added — a user with a
        // pattern / PIN / biometric lock sees the mission
        // UI directly, matching the user's mental model
        // that a strong-mode alarm fires NOW.
        //
        // The flags are set BEFORE `super.onCreate` returns
        // its Window so the first frame paints on top of
        // any existing lockscreen. (Setting them later
        // would race the first frame on cold launch.)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
            )
        } else {
            // API < 27: FLAG_DISMISS_KEYGUARD and
            // FLAG_TURN_SCREEN_ON are API 27+. The
            // pre-27 fall-back uses FLAG_SHOW_WHEN_LOCKED
            // (API 5+) and FLAG_KEEP_SCREEN_ON (API 1+).
            // The user may still need to swipe / unlock;
            // that is acceptable on the legacy path
            // (minSdk is 30 per v1.1i so this branch is
            // effectively unreachable on do it).
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
            )
        }
    }

    override fun getInitialRoute(): String {
        // Read the launching intent's extras and encode
        // them into the `/mission?...` query string. The
        // Flutter embedding hands this string to
        // `MaterialApp.onGenerateRoute` on the first
        // frame; the Dart side parses the query string
        // via `RouteSettings.arguments` (set in
        // `lib/main.dart`).
        //
        // Extras:
        //   mode     - "habit" (default) or "overlay"
        //   habitId  - present iff mode=habit
        //   title    - present iff mode=overlay
        //   body     - present iff mode=overlay
        val intent = intent
        val mode = intent?.getStringExtra(EXTRA_MODE) ?: MODE_HABIT
        return when (mode) {
            MODE_OVERLAY -> buildOverlayRoute(intent)
            else -> buildHabitRoute(intent)
        }
    }

    private fun buildHabitRoute(intent: Intent?): String {
        val habitId = intent?.getStringExtra(EXTRA_HABIT_ID).orEmpty()
        return "/mission?mode=$MODE_HABIT&habitId=${Uri.encode(habitId)}"
    }

    private fun buildOverlayRoute(intent: Intent?): String {
        val title = intent?.getStringExtra(EXTRA_TITLE).orEmpty()
        val body = intent?.getStringExtra(EXTRA_BODY).orEmpty()
        val sb = StringBuilder("/mission?mode=$MODE_OVERLAY")
        if (title.isNotEmpty()) sb.append("&title=").append(Uri.encode(title))
        if (body.isNotEmpty()) sb.append("&body=").append(Uri.encode(body))
        return sb.toString()
    }

    companion object {
        /**
         * Intent extra keys. The Kotlin-side
         * `FullScreenIntentChannel` writes these when it
         * builds the launch Intent; the Dart side reads
         * them via the route query string parsed by
         * `MaterialApp.onGenerateRoute`.
         *
         * Centralized here so the launch handler and the
         * `getInitialRoute` parser cannot drift.
         */
        const val EXTRA_MODE = "doit.fsi.mode"
        const val EXTRA_HABIT_ID = "doit.fsi.habitId"
        const val EXTRA_TITLE = "doit.fsi.title"
        const val EXTRA_BODY = "doit.fsi.body"

        /** Launch modes. */
        const val MODE_HABIT = "habit"
        const val MODE_OVERLAY = "overlay"

        /**
         * Build a launch Intent for the strong-mode habit
         * mission flow. The Intent is fired by
         * `FullScreenIntentChannel.showHabitMission(ctx,
         * args)` after `PendingIntent.getActivity(...)`.
         */
        fun habitIntent(ctx: Context, habitId: String): Intent =
            Intent(ctx, FullScreenActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                putExtra(EXTRA_MODE, MODE_HABIT)
                putExtra(EXTRA_HABIT_ID, habitId)
            }

        /**
         * Build a launch Intent for the routine-fired
         * full-screen overlay flow.
         */
        fun overlayIntent(
            ctx: Context,
            title: String?,
            body: String?,
        ): Intent =
            Intent(ctx, FullScreenActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                putExtra(EXTRA_MODE, MODE_OVERLAY)
                if (title != null) putExtra(EXTRA_TITLE, title)
                if (body != null) putExtra(EXTRA_BODY, body)
            }
    }
}

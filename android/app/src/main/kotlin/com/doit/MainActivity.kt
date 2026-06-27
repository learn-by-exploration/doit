package com.doit

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    /**
     * v1.4k / Phase 38 / SYS-125 / ADR-055 / WF-052.
     * The widget body-tap PendingIntent
     * (`WidgetRenderer.openAppIntent`) sets this extra
     * to the cached `selectedHabitId` (the picked do
     * for this widget instance). The activity reads it
     * in [getInitialRoute] and encodes the route as
     * `/habit?habitId=...` for the Dart
     * `MaterialApp.onGenerateRoute` to resolve.
     *
     * Key namespace is distinct from
     * [DoitWidgetProvider.EXTRA_HABIT_ID]
     * (`com.doit.EXTRA_HABIT_ID`): the provider
     * receives the action-broadcast extras (markDone /
     * skip / undo); the activity receives the body-tap
     * extras. Different key prevents a stale action
     * broadcast from being misread as a body-tap deep
     * link.
     */
    override fun getInitialRoute(): String? {
        val intent = intent ?: return null
        val habitId = intent.getStringExtra(EXTRA_HABIT_ID).orEmpty()
        // Clear the extra so a config change (rotation)
        // does not re-route to the widget's picked do
        // after the user has navigated away. The deep
        // link is a one-shot — once the activity lands
        // on `/habit?habitId=...` and the user pops back
        // to HomeScreen, the route should not re-fire.
        intent.removeExtra(EXTRA_HABIT_ID)
        if (habitId.isEmpty()) return null
        return "/habit?habitId=${Uri.encode(habitId)}"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ReminderChannelProxy.setAppContext(applicationContext)
        ReminderChannelProxy.attach(flutterEngine)
        // v1.0 / Phase D PR 1 / ADR-022: device-state probe
        // channel. Same attach / detach lifecycle as the
        // reminders channel; the receivers are
        // (un)registered in the channel's startStream /
        // stopStream methods, not here.
        DeviceStateChannel.setAppContext(applicationContext)
        DeviceStateChannel.attach(flutterEngine)
        // v1.0 / Phase E PR 1 / ADR-023: calendar probe
        // channel. Watches CalendarContract.Instances via
        // a ContentObserver; pushes busy-change events
        // to the Dart side. The Dart matching engine
        // (RoutineExecutor) decides whether each event
        // matches a registered TriggerCalendarEvent.
        CalendarChannel.setAppContext(applicationContext)
        CalendarChannel.attach(flutterEngine)
        // v1.0 / Phase F PR 1 / ADR-019: call-screening
        // channel + CallScreeningService. The OS invokes
        // CallInterceptor.onScreenCall(...) for every
        // incoming call; the service returns a synchronous
        // CallResponse and forwards the event to Dart via
        // the doit/call_interceptor MethodChannel. The
        // matching engine (RoutineExecutor) dispatches the
        // Japan-routine automations based on the configured
        // contact list and ringer state.
        CallInterceptor.setAppContext(applicationContext)
        // v1.1h-followup: `FlutterEngine.activity` getter was
        // removed in the modern embedding. Pass the Activity
        // explicitly so the screening-role request (which
        // needs `startActivityForResult`) can find a live
        // Activity to launch from. MainActivity is responsible
        // for clearing the reference in onDestroy.
        CallInterceptor.setActivity(this)
        CallInterceptor.attach(flutterEngine)

        // v1.3c / Phase 14 / SYS-113 / ADR-043: full-screen
        // intent probe + deep-link channel. The Kotlin side
        // resolves the API 32/33/34 asymmetry (Dart side is
        // platform-agnostic); the activity launch path
        // (Phase 6a proper) will extend the same channel
        // with `showHabitMission` + `showRoutineOverlay`
        // handlers without re-doing this wiring.
        FullScreenIntentChannel.setAppContext(applicationContext)
        FullScreenIntentChannel.attach(flutterEngine)

        // v1.4a / Phase 28 / SYS-115 / ADR-045 / WF-042:
        // home widget channel. Wired here so the inbound
        // Dart side (WidgetService) can ask the Kotlin
        // side to repaint every bound widget via
        // WidgetUpdater.refreshAll. The widget's own
        // DoitWidgetProvider attaches a separate one-shot
        // FlutterEngine on demand (see WidgetUpdater) so
        // the widget host process survives the OS killing
        // the MainActivity process.
        WidgetChannel.setAppContext(applicationContext)
        WidgetChannel.attach(flutterEngine)

        // v1.2e / Phase 5: ensure the reminder notification
        // channel is registered before the first alarm fires.
        // The channel id MUST match `kNotificationChannelId`
        // (`doit.reminders`) in
        // `lib/reminders/notification_service.dart`; the
        // channel is upgrade-safe (existing installs keep
        // their user-set importance).
        ensureNotificationChannel(applicationContext)
    }

    override fun onDestroy() {
        // Drop the Activity reference so a destroyed
        // Activity is not retained across configuration
        // changes or process restarts. setActivity(null)
        // is paired with setActivity(this) above; both
        // happen in MainActivity only.
        CallInterceptor.setActivity(null)
        CallInterceptor.detach()
        // v1.3c / Phase 14 / SYS-113 / ADR-043: tear
        // down the FSI channel in the same lifecycle slot
        // as the other channels. Order matters only because
        // all four channels are independent — the reverse
        // of attach() is fine.
        FullScreenIntentChannel.detach()
        // v1.4a / Phase 28 / SYS-115: tear down the widget
        // channel. The widget's own DoitWidgetProvider
        // attaches a separate one-shot engine on demand
        // (see WidgetUpdater) — that engine is process-
        // scoped and not tied to MainActivity.
        WidgetChannel.detach()
        CalendarChannel.detach()
        DeviceStateChannel.detach()
        ReminderChannelProxy.detach()
        super.onDestroy()
    }

    companion object {
        const val NOTIFICATION_CHANNEL_ID = "doit.reminders"

        /**
         * v1.4k / Phase 38 / SYS-125 / ADR-055 / WF-052.
         * Body-tap extra set by [WidgetRenderer.openAppIntent]
         * when the cached `selectedHabitId` is non-empty.
         * Read by [getInitialRoute] to encode
         * `/habit?habitId=...`. Distinct from
         * [DoitWidgetProvider.EXTRA_HABIT_ID] (which
         * carries the action-broadcast target id).
         */
        const val EXTRA_HABIT_ID = "com.doit.EXTRA_HABIT_ID_FROM_WIDGET"

        /**
         * Idempotently register the `doit.reminders` channel
         * with high importance. Called from
         * `configureFlutterEngine` and from
         * `buildReminderNotification` (so unit tests that
         * construct the channel in isolation still get a
         * registered channel).
         */
        fun ensureNotificationChannel(ctx: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val mgr = ctx.getSystemService(Context.NOTIFICATION_SERVICE)
                as NotificationManager
            if (mgr.getNotificationChannel(NOTIFICATION_CHANNEL_ID) != null) return
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Do it reminders",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Daily reminders for your dos."
                enableVibration(true)
            }
            mgr.createNotificationChannel(channel)
        }

        /**
         * Build the reminder Notification for [alarmId].
         * v1.2e / Phase 5: bodies with non-null [body] are
         * forwarded verbatim (routine-fired notifications,
         * v1.1b / SYS-085); null bodies fall back to a
         * default "Time for <habitName>".
         *
         * v1.3d / Phase 15 / SYS-114 / ADR-044:
         * `strongMode = true` notifications now target
         * `FullScreenActivity` (the strong-mode mission
         * UI) and set `.setFullScreenIntent(openPi, true)`
         * so the OS launches the activity directly when
         * the alarm fires and the device is locked —
         * honoring the strong-mode interruption contract
         * without requiring the user to tap the
         * notification first. Soft-mode notifications
         * keep the existing `MainActivity` openPi (no
         * FSI); tapping the notification or the "Done"
         * action opens the home screen.
         *
         * The notification id matches the alarm id so a
         * follow-up `NotificationManager.cancel(alarmId)`
         * removes exactly this one — never a sibling alarm.
         */
        fun buildReminderNotification(
            ctx: Context,
            alarmId: Int,
            habitName: String,
            body: String?,
            strongMode: Boolean,
            habitId: String? = null,
        ): Notification {
            ensureNotificationChannel(ctx)
            val title = habitName
            val text = body ?: "Time for $habitName"
            val builder = NotificationCompat.Builder(ctx, NOTIFICATION_CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle(title)
                .setContentText(text)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
            if (strongMode && habitId != null) {
                // v1.3d / SYS-114: the strong-mode
                // openIntent targets `FullScreenActivity`
                // with the `habitId` extra. The activity's
                // `getInitialRoute()` encodes it into
                // `/mission?mode=habit&habitId=...`; the
                // Dart `MissionLauncherScreen` parses the
                // route and looks up the habit via
                // `DoRepository.instance.getById(habitId)`.
                val fsiIntent = FullScreenActivity.habitIntent(ctx, habitId)
                val fsiPi = PendingIntent.getActivity(
                    ctx, alarmId, fsiIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or
                        PendingIntent.FLAG_IMMUTABLE,
                )
                builder.setContentIntent(fsiPi)
                // v1.3d / SYS-114: `setFullScreenIntent`
                // tells the OS to launch the activity
                // directly when the alarm fires — even if
                // the device is locked. This is the
                // strong-mode interruption contract; on
                // API 34+ the OS suppresses the FSI
                // unless `USE_FULL_SCREEN_INTENT` is
                // granted (handled by the Phase 14 /
                // v1.3c / SYS-113 probe + deep-link).
                builder.setFullScreenIntent(fsiPi, true)
                builder.addAction(0, "Open", fsiPi)
            } else {
                // Soft-mode (and the legacy "no habitId"
                // path): open `MainActivity`. The home
                // screen handles the "Done" tap as a
                // soft completion.
                val openIntent = Intent(
                    ctx,
                    MainActivity::class.java,
                ).apply {
                    flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
                }
                val openPi = PendingIntent.getActivity(
                    ctx, alarmId, openIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or
                        PendingIntent.FLAG_IMMUTABLE,
                )
                builder.setContentIntent(openPi)
                builder.addAction(0, "Done", openPi)
            }
            return builder.build()
        }
    }
}
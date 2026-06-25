package com.doit

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
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
        CalendarChannel.detach()
        DeviceStateChannel.detach()
        ReminderChannelProxy.detach()
        super.onDestroy()
    }

    companion object {
        const val NOTIFICATION_CHANNEL_ID = "doit.reminders"

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
        ): Notification {
            ensureNotificationChannel(ctx)
            val openIntent = Intent(ctx, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            val openPi = PendingIntent.getActivity(
                ctx, alarmId, openIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val title = habitName
            val text = body ?: "Time for $habitName"
            val builder = NotificationCompat.Builder(ctx, NOTIFICATION_CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle(title)
                .setContentText(text)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setContentIntent(openPi)
            // The "Done" / "Open" action set lives here so
            // future v1.x releases can route the action
            // through PendingIntent.getBroadcast into the
            // Dart side; for now both actions open the app
            // (the home screen / mission screen are picked
            // by the route from there).
            if (strongMode) {
                builder.addAction(0, "Open", openPi)
            } else {
                builder.addAction(0, "Done", openPi)
            }
            return builder.build()
        }
    }
}
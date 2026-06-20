package com.doit

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
    }

    override fun onDestroy() {
        CalendarChannel.detach()
        DeviceStateChannel.detach()
        ReminderChannelProxy.detach()
        super.onDestroy()
    }
}

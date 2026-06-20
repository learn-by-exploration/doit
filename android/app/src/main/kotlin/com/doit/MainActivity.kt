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
        CallInterceptor.attach(flutterEngine)
    }

    override fun onDestroy() {
        CallInterceptor.detach()
        CalendarChannel.detach()
        DeviceStateChannel.detach()
        ReminderChannelProxy.detach()
        super.onDestroy()
    }
}
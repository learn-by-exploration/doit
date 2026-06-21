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
        // v1.1h-followup: `FlutterEngine.activity` getter was
        // removed in the modern embedding. Pass the Activity
        // explicitly so the screening-role request (which
        // needs `startActivityForResult`) can find a live
        // Activity to launch from. MainActivity is responsible
        // for clearing the reference in onDestroy.
        CallInterceptor.setActivity(this)
        CallInterceptor.attach(flutterEngine)
    }

    override fun onDestroy() {
        // Drop the Activity reference so a destroyed
        // Activity is not retained across configuration
        // changes or process restarts. setActivity(null)
        // is paired with setActivity(this) above; both
        // happen in MainActivity only.
        CallInterceptor.setActivity(null)
        CallInterceptor.detach()
        CalendarChannel.detach()
        DeviceStateChannel.detach()
        ReminderChannelProxy.detach()
        super.onDestroy()
    }
}
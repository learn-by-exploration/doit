package com.common_games.streak

import android.app.AlarmManager
import android.content.Context
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Thin Kotlin-side adapter for the `streak/reminders` method
 * channel.
 *
 * Responsibilities:
 *   - Receive calls from Dart (setExact, cancel, fireAlarm) and
 *     route them to AlarmManager.
 *   - Receive calls from Android (BootReceiver, AlarmReceiver)
 *     and route them to Dart via the channel.
 *
 * The Dart side is the source of truth for "which alarms are
 * pending and when they should fire". The Kotlin side is
 * stateless w.r.t. the schedule — it only knows how to talk to
 * AlarmManager.
 */
object ReminderChannelProxy {
    private const val CHANNEL = "streak/reminders"
    private var channel: MethodChannel? = null

    fun attach(engine: FlutterEngine) {
        val ch = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "setExact" -> {
                    val alarmId = call.argument<Int>("alarmId")
                    val epochMs = call.argument<Number>("epochMs")?.toLong()
                    if (alarmId == null || epochMs == null) {
                        result.error("BAD_ARGS", "alarmId and epochMs are required", null)
                    } else {
                        setExact(alarmId, epochMs, call.argument<Boolean>("allowWhileIdle") ?: true)
                        result.success(null)
                    }
                }
                "cancel" -> {
                    val alarmId = call.argument<Int>("alarmId")
                    if (alarmId == null) {
                        result.error("BAD_ARGS", "alarmId is required", null)
                    } else {
                        cancel(alarmId)
                        result.success(null)
                    }
                }
                "probeReliability" -> {
                    val reliability = probeReliability()
                    result.success(reliability)
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

    private fun setExact(alarmId: Int, epochMs: Long, allowWhileIdle: Boolean) {
        val ctx = appContext ?: return
        val mgr = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = AlarmReceiver.pendingIntent(ctx, alarmId)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Android 12+: try exact; if denied, fall back to
            // setAndAllowWhileIdle (which is exact-ish — runs in
            // a maintenance window, may be up to 15 min late).
            if (mgr.canScheduleExactAlarms()) {
                if (allowWhileIdle) {
                    mgr.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, epochMs, pi)
                } else {
                    mgr.setExact(AlarmManager.RTC_WAKEUP, epochMs, pi)
                }
            } else {
                mgr.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, epochMs, pi)
            }
        } else {
            if (allowWhileIdle) {
                mgr.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, epochMs, pi)
            } else {
                mgr.setExact(AlarmManager.RTC_WAKEUP, epochMs, pi)
            }
        }
    }

    private fun cancel(alarmId: Int) {
        val ctx = appContext ?: return
        val mgr = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = AlarmReceiver.pendingIntent(ctx, alarmId)
        mgr.cancel(pi)
        pi.cancel()
    }

    private fun probeReliability(): String {
        val ctx = appContext ?: return "unknown"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val mgr = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            return if (mgr.canScheduleExactAlarms()) "optimal" else "degraded"
        }
        return "optimal"
    }

    @Volatile
    private var appContext: Context? = null

    fun setAppContext(ctx: Context) {
        appContext = ctx.applicationContext
    }

    fun rescheduleAll(ctx: Context) {
        appContext = ctx.applicationContext
        channel?.invokeMethod("rescheduleAll", null)
    }

    fun fireAlarm(ctx: Context, alarmId: Int) {
        appContext = ctx.applicationContext
        channel?.invokeMethod("fireAlarm", mapOf("alarmId" to alarmId))
    }

    fun recordAnchor(ctx: Context, atIso: String) {
        appContext = ctx.applicationContext
        channel?.invokeMethod("recordAnchor", mapOf("atIso" to atIso))
    }
}

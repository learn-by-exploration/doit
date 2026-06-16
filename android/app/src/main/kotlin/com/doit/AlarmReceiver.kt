package com.doit

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * Receives the AlarmManager broadcast. Hands off to the Dart
 * side via the `doit/reminders` method channel (call:
 * `fireAlarm(alarmId)`) so the Dart side can:
 *   1. Show the notification (or full-screen intent for
 *      Strong-mode habits).
 *   2. Schedule the next occurrence of the habit.
 *
 * On Android 12+ (S, API 31+) the SCHEDULE_EXACT_ALARM
 * permission is required. If the user denied it, AlarmManager
 * routes the call to `setAndAllowWhileIdle` instead — see
 * `ReminderChannelProxy.setExact` for the fallback path.
 *
 * See docs/v_model/notification_reliability.md § Layer 1.
 */
class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val alarmId = intent.getIntExtra(EXTRA_ALARM_ID, -1)
        if (alarmId == -1) return
        ReminderChannelProxy.fireAlarm(context, alarmId)
    }

    companion object {
        const val EXTRA_ALARM_ID = "alarm_id"

        fun pendingIntent(context: Context, alarmId: Int): PendingIntent {
            val intent = Intent(context, AlarmReceiver::class.java).apply {
                action = "com.doit.FIRE_ALARM"
                putExtra(EXTRA_ALARM_ID, alarmId)
            }
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            return PendingIntent.getBroadcast(context, alarmId, intent, flags)
        }
    }
}

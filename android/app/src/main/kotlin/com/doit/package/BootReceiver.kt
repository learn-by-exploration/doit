package com.doit.package

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Re-arms every pending alarm on:
 *   - ACTION_BOOT_COMPLETED
 *   - ACTION_LOCKED_BOOT_COMPLETED (preferred; reschedules before unlock)
 *   - ACTION_MY_PACKAGE_REPLACED (the app was updated)
 *   - ACTION_TIMEZONE_CHANGED (the device zone changed)
 *
 * The receiver is short-lived. It hands off to the Dart side
 * via the `doit/reminders` method channel (call:
 * `rescheduleAll`) and the Dart side reads the local DB and
 * re-arms each pending alarm through AlarmManager.
 *
 * See docs/v_model/notification_reliability.md § Layer 3.
 */
class BootReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    val action = intent.action ?: return
    when (action) {
      Intent.ACTION_BOOT_COMPLETED,
      Intent.ACTION_LOCKED_BOOT_COMPLETED,
      Intent.ACTION_MY_PACKAGE_REPLACED,
      Intent.ACTION_TIMEZONE_CHANGED -> {
        ReminderChannelProxy.rescheduleAll(context)
      }
    }
  }
}

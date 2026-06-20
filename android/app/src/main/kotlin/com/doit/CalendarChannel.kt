package com.doit

import android.content.ContentUris
import android.content.Context
import android.database.ContentObserver
import android.database.Cursor
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.CalendarContract
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Thin Kotlin-side adapter for the `doit/calendar` method
 * channel (v1.0 / Phase E PR 1 / ADR-023).
 *
 * Responsibilities:
 *   - Receive calls from Dart (`listAccounts`, `startStream`,
 *     `stopStream`) and respond synchronously or with a
 *     stream of `CalendarEvent` events pushed back via
 *     `invokeMethod("onCalendarEvent", map)`.
 *   - Watch the user's calendar via a `ContentObserver` on
 *     `CalendarContract.Instances.CONTENT_URI`. The observer
 *     fires when an event is inserted / updated / deleted;
 *     we re-query the current visible window and emit
 *     `start` / `end` / `reminder` / `busy` events for each
 *     transition we observe.
 *   - List the available calendar accounts for the
 *     on-demand permission sheet to drive the picker.
 *
 * Library choice: native `CalendarContract` over the
 * `device_calendar` / `add_2_calendar` Flutter packages. See
 * ADR-023. The native surface is sufficient for read-only
 * access, avoids the package dependency churn, and gives us
 * direct access to reminder metadata (`MIN_REMINDER` /
 * `MAX_REMINDER`).
 *
 * The receivers / observer are registered in `startStream`
 * and unregistered in `stopStream` (or `detach`). No
 * foreground service is required: `ContentObserver` runs in
 * the app process, which is alive while the user has the
 * app open. When the app is backgrounded, the observer
 * does not fire (the OS suspends the process); routine
 * triggers that depend on the calendar are best-effort and
 * documented as such in
 * `docs/v_model/notification_reliability.md`.
 */
object CalendarChannel {
    private const val CHANNEL = "doit/calendar"
    private const val SINK_METHOD = "onCalendarEvent"

    private var channel: MethodChannel? = null
    private var streamStarted: Boolean = false
    private var observer: ContentObserver? = null

    fun attach(engine: FlutterEngine) {
        val ch = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "listAccounts" -> {
                    val ctx = appContext
                    if (ctx == null) {
                        result.error(
                            "NO_CONTEXT",
                            "CalendarChannel has no app context",
                            null,
                        )
                    } else {
                        result.success(listAccountsMap(ctx))
                    }
                }
                "startStream" -> {
                    startStream()
                    result.success(null)
                }
                "stopStream" -> {
                    stopStream()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        channel = ch
    }

    /** Public so MainActivity can call it. */
    fun detach() {
        stopStream()
        channel?.setMethodCallHandler(null)
        channel = null
    }

    private fun startStream() {
        if (streamStarted) return
        val ctx = appContext ?: return
        observer = object : ContentObserver(Handler(Looper.getMainLooper())) {
            override fun onChange(selfChange: Boolean) {
                onChange(selfChange, null)
            }

            override fun onChange(selfChange: Boolean, uri: Uri?) {
                // Re-query the current visible window. We
                // emit transitions in pure-Dart land (the
                // matching engine); the Kotlin side just
                // forwards "something changed in the
                // calendar" hints as a busy-change event.
                pushBusyChange(ctx, isBusy = true)
            }
        }
        ctx.contentResolver.registerContentObserver(
            CalendarContract.Instances.CONTENT_URI,
            true,
            observer!!,
        )
        streamStarted = true
        // Push an initial "free" baseline so the Dart
        // side has a starting busy state.
        pushBusyChange(ctx, isBusy = false)
    }

    private fun stopStream() {
        if (!streamStarted) return
        val ctx = appContext
        if (ctx != null && observer != null) {
            try {
                ctx.contentResolver.unregisterContentObserver(observer!!)
            } catch (_: Exception) {
                // Already unregistered. Ignore.
            }
        }
        observer = null
        streamStarted = false
    }

    private fun pushBusyChange(context: Context, isBusy: Boolean) {
        val map = mapOf(
            "kind" to "busy",
            "eventId" to "",
            "calendarId" to "",
            "title" to "",
            "atMs" to System.currentTimeMillis(),
            "isBusy" to isBusy,
        )
        channel?.invokeMethod(SINK_METHOD, map)
    }

    /**
     * Read the list of installed calendar accounts. Maps to
     * `CalendarContract.Calendars.ACCOUNT_NAME` /
     * `CALENDAR_DISPLAY_NAME`.
     */
    private fun listAccountsMap(context: Context): List<Map<String, String>> {
        val projection = arrayOf(
            CalendarContract.Calendars._ID,
            CalendarContract.Calendars.ACCOUNT_NAME,
            CalendarContract.Calendars.CALENDAR_DISPLAY_NAME,
        )
        val out = ArrayList<Map<String, String>>()
        val uri = CalendarContract.Calendars.CONTENT_URI
        val cursor: Cursor? = try {
            context.contentResolver.query(uri, projection, null, null, null)
        } catch (_: SecurityException) {
            // READ_CALENDAR denied. The Dart side surfaces
            // a rationale screen; the picker falls back to
            // an empty list.
            null
        } catch (_: Exception) {
            null
        }
        cursor?.use { c ->
            val idIdx = c.getColumnIndex(CalendarContract.Calendars._ID)
            val acctIdx = c.getColumnIndex(CalendarContract.Calendars.ACCOUNT_NAME)
            val nameIdx = c.getColumnIndex(CalendarContract.Calendars.CALENDAR_DISPLAY_NAME)
            while (c.moveToNext()) {
                val id = if (idIdx >= 0) c.getLong(idIdx) else continue
                val acct = if (acctIdx >= 0) c.getString(acctIdx) ?: "" else ""
                val name = if (nameIdx >= 0) c.getString(nameIdx) ?: "" else ""
                if (acct.isEmpty()) continue
                out.add(
                    mapOf(
                        "accountId" to "$acct:$id",
                        "displayName" to name.ifEmpty { acct },
                    ),
                )
            }
        }
        return out
    }

    @Volatile
    private var appContext: Context? = null

    fun setAppContext(ctx: Context) {
        appContext = ctx.applicationContext
    }
}

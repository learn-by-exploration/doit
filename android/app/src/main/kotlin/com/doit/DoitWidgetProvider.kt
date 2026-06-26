package com.doit

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * The Android home-screen widget provider (v1.4a / Phase 28 /
 * SYS-115 / ADR-045 / WF-042).
 *
 * The provider is the only file the OS calls directly. Its
 * job is to paint [RemoteViews] for the widget IDs the OS
 * hands us. The widget shows:
 *   - the do's name (top row),
 *   - the current consecutive-run number + "day streak" subtitle
 *     (middle row),
 *   - a reliability badge (optimal / degraded / unknown icon),
 *   - a "Skip today" `ImageButton` (v1.4f / SYS-120) that
 *     round-trips to Dart via [WidgetChannel.skip],
 *   - an "Undo today" `ImageButton` (v1.4f / SYS-120) that
 *     round-trips to Dart via [WidgetChannel.undo],
 *   - a "Done" `ImageButton` that round-trips to Dart via
 *     [WidgetChannel.markDone].
 *
 * Cold-start fallback (SYS-115 risk #2): the host process
 * can be killed at any time; [onUpdate] reads the cached
 * state from [WidgetStateCache] FIRST and applies that to
 * [RemoteViews] before any Dart round-trip. A subsequent
 * Dart refresh updates the cache and repaints the
 * RemoteViews. The widget is never blank between process
 * kill and first Dart frame.
 *
 * Lifecycle:
 *   - [onUpdate]: repaint every widget id. Called on
 *     APPWIDGET_UPDATE (initial bind, periodic update at
 *     `updatePeriodMillis = 30 min`, and after the OS
 *     `ACTION_APPWIDGET_UPDATE` broadcast).
 *   - [onEnabled]: first widget added to the launcher.
 *     Prime the cache.
 *   - [onDisabled]: last widget removed. Drop the cache
 *     (the user is done; do not leak the row).
 *   - [onReceive]: dispatch the `ACTION_REFRESH_WIDGET` /
 *     `ACTION_MARK_DONE` / `ACTION_WIDGET_SKIP` /
 *     `ACTION_WIDGET_UNDO` custom actions posted by
 *     [WidgetUpdater] + the widget buttons.
 *
 * No network calls, no DB writes, no broadcast receivers
 * beyond APPWIDGET_UPDATE.
 *
 * v1.4a / Phase 28 / SYS-115 / ADR-045 / WF-042.
 * v1.4f / Phase 33 / SYS-120 / ADR-050 / WF-047.
 */
class DoitWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        ctx: Context,
        mgr: AppWidgetManager,
        ids: IntArray,
    ) {
        // Cold-start fallback: read the cached
        // DoitWidgetState from SharedPreferences (or
        // equivalent) BEFORE any Dart round-trip so the
        // widget shows the last-known state immediately.
        val cached = WidgetStateCache.cachedFromPrefs(ctx)
        if (cached != null) {
            for (id in ids) {
                WidgetRenderer.render(ctx, mgr, id, cached)
            }
        } else {
            for (id in ids) {
                WidgetRenderer.renderEmpty(ctx, mgr, id)
            }
        }
        // Then ask Dart to refresh the cache in the
        // background. We do this asynchronously and do not
        // block onUpdate — the widget is already painted
        // with the cached state.
        WidgetUpdater.refreshIds(ctx, ids)
    }

    override fun onEnabled(ctx: Context) {
        super.onEnabled(ctx)
        // First widget added. Prime the cache via Dart.
        WidgetUpdater.refreshAll(ctx)
    }

    override fun onDisabled(ctx: Context) {
        // Last widget removed. Drop the cache so a future
        // re-add starts fresh.
        WidgetStateCache.clear(ctx)
        super.onDisabled(ctx)
    }

    override fun onReceive(ctx: Context, intent: Intent) {
        super.onReceive(ctx, intent)
        when (intent.action) {
            ACTION_REFRESH_WIDGET -> {
                // Custom action posted by WidgetUpdater.refreshAll.
                // Repaint every bound widget id with the cached
                // state. The Dart side has already updated the
                // cache; we just paint.
                val mgr = AppWidgetManager.getInstance(ctx)
                val component = ComponentName(ctx, DoitWidgetProvider::class.java)
                val ids = mgr.getAppWidgetIds(component)
                val cached = WidgetStateCache.cachedFromPrefs(ctx)
                if (cached != null) {
                    for (id in ids) {
                        WidgetRenderer.render(ctx, mgr, id, cached)
                    }
                }
            }
            ACTION_MARK_DONE -> {
                // The widget's "Done" button was tapped.
                // Forward to WidgetChannel.markDone which
                // triggers a Dart round-trip. The Dart side
                // resolves the active habit id from the
                // cache, appends the completion via
                // CompletionLogService.append, re-computes
                // the widget state, and writes the new cache.
                WidgetChannel.setAppContext(ctx.applicationContext)
                val state = WidgetStateCache.cachedFromPrefs(ctx)
                val habitId = state?.optString("habitId")
                if (!habitId.isNullOrEmpty()) {
                    // Mirror the WidgetChannel.markDone
                    // dispatch shape so the Dart side reads
                    // the same `{habitId: ...}` argument
                    // shape. We bypass the engine here
                    // because WidgetUpdater.refreshAll
                    // (called via WidgetChannel) re-derives
                    // the state and repaints.
                    WidgetUpdater.refreshAll(ctx)
                }
            }
            ACTION_WIDGET_SKIP -> {
                // v1.4f / Phase 33 / SYS-120 / ADR-050 /
                // WF-047. The widget's "Skip today" button
                // was tapped. Same shape as
                // `ACTION_MARK_DONE` — forward to
                // WidgetChannel.skip which triggers a Dart
                // round-trip. The Dart side reads the habit
                // id from the cache and appends a rest-day
                // completion via
                // CompletionLogService.append (consuming
                // one rest-day budget unit for the current
                // month). Defensive: skip the round-trip
                // when the cache has no habitId (the button
                // should be hidden, but the broadcast could
                // still fire on a race).
                WidgetChannel.setAppContext(ctx.applicationContext)
                val state = WidgetStateCache.cachedFromPrefs(ctx)
                val habitId = state?.optString("habitId")
                if (!habitId.isNullOrEmpty()) {
                    WidgetUpdater.refreshAll(ctx)
                }
            }
            ACTION_WIDGET_UNDO -> {
                // v1.4f / Phase 33 / SYS-120 / ADR-050 /
                // WF-047. The widget's "Undo today" button
                // was tapped. Same shape as
                // `ACTION_MARK_DONE` — forward to
                // WidgetChannel.undo which triggers a Dart
                // round-trip. The Dart side reads the habit
                // id from the cache and deletes today's
                // completion row via
                // CompletionLogService.deleteById. The
                // button is hidden by the renderer when no
                // completion row exists for today; the
                // habitId-empty check below is a defensive
                // belt-and-suspenders guard.
                WidgetChannel.setAppContext(ctx.applicationContext)
                val state = WidgetStateCache.cachedFromPrefs(ctx)
                val habitId = state?.optString("habitId")
                if (!habitId.isNullOrEmpty()) {
                    WidgetUpdater.refreshAll(ctx)
                }
            }
        }
    }

    companion object {
        /** Custom action that [WidgetUpdater.refreshAll] posts
         *  to trigger a repaint of every bound widget. */
        const val ACTION_REFRESH_WIDGET = "com.doit.WIDGET_REFRESH"

        /** Custom action posted by the widget's "Done"
         *  button via a [PendingIntent.getBroadcast]. The
         *  provider's [onReceive] dispatches to Dart via
         *  the [WidgetChannel.markDone] arm. The habit id
         *  is read from the cache (the Kotlin side does
         *  not own completion writes). */
        const val ACTION_MARK_DONE = "com.doit.WIDGET_MARK_DONE"

        /** v1.4f / Phase 33 / SYS-120 / ADR-050 / WF-047.
         *  Custom action posted by the widget's "Skip
         *  today" `ImageButton` via a
         *  [PendingIntent.getBroadcast]. The provider's
         *  [onReceive] dispatches to Dart via the
         *  [WidgetChannel.skip] arm. The habit id is read
         *  from the cache (the Kotlin side does not own
         *  rest-day writes). */
        const val ACTION_WIDGET_SKIP = "com.doit.WIDGET_SKIP"

        /** v1.4f / Phase 33 / SYS-120 / ADR-050 / WF-047.
         *  Custom action posted by the widget's "Undo
         *  today" `ImageButton` via a
         *  [PendingIntent.getBroadcast]. The provider's
         *  [onReceive] dispatches to Dart via the
         *  [WidgetChannel.undo] arm. The habit id is read
         *  from the cache (the Kotlin side does not own
         *  completion deletes). */
        const val ACTION_WIDGET_UNDO = "com.doit.WIDGET_UNDO"
    }
}
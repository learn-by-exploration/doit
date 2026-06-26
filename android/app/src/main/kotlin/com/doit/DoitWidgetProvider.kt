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
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

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
 *     round-trips to Dart via [WidgetChannel.invokeAction],
 *   - an "Undo today" `ImageButton` (v1.4f / SYS-120) that
 *     round-trips to Dart via [WidgetChannel.invokeAction],
 *   - a "Done" `ImageButton` that round-trips to Dart via
 *     [WidgetChannel.invokeAction].
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
 * v1.4g / Phase 34 / SYS-121 / ADR-051 / WF-048: the
 * three widget action arms (`ACTION_MARK_DONE` /
 * `ACTION_WIDGET_SKIP` / `ACTION_WIDGET_UNDO`) now
 * route through [WidgetChannel.invokeAction] which
 * sends an INBOUND `MethodChannel` call to the Dart-side
 * [com.doit.widget.WidgetActionInvoker] so the actual
 * completion write / rest-day append / row delete goes
 * through Dart's [com.doit.services.WidgetService].
 * v1.4a + v1.4f shipped the buttons WITHOUT the
 * round-trip (only repainted via [WidgetUpdater.refreshAll])
 * — closing the latent gap is the v1.4g scope.
 *
 * No network calls, no DB writes, no broadcast receivers
 * beyond APPWIDGET_UPDATE.
 *
 * v1.4a / Phase 28 / SYS-115 / ADR-045 / WF-042.
 * v1.4f / Phase 33 / SYS-120 / ADR-050 / WF-047.
 * v1.4g / Phase 34 / SYS-121 / ADR-051 / WF-048.
 */
class DoitWidgetProvider : AppWidgetProvider() {
    /**
     * Coroutine scope for the suspending
     * [WidgetChannel.invokeAction] calls. We use the IO
     * dispatcher because the channel call posts to the
     * platform main thread and awaits a Dart-side result;
     * using IO keeps [onReceive] non-blocking on the main
     * thread.
     */
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

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
                // v1.4g / Phase 34 / SYS-121 / ADR-051 /
                // WF-048. The widget's "Done" button was
                // tapped. Forward to [WidgetChannel.invokeAction]
                // which sends an INBOUND `MethodChannel` call
                // to Dart's [WidgetActionInvoker]. The Dart
                // side resolves the active habit id from
                // the cache (or, in this case, from the
                // intent extras — the widget's "Done"
                // PendingIntent sets `EXTRA_HABIT_ID` for
                // the case where the cache is stale), then
                // appends the completion via
                // [CompletionLogService], re-derives the
                // state, and writes the new cache. We
                // launch the suspending `invokeAction` on
                // the IO dispatcher so the BroadcastReceiver
                // doesn't block the main thread.
                WidgetChannel.setAppContext(ctx.applicationContext)
                val habitId = intent.getStringExtra(EXTRA_HABIT_ID)
                    ?: WidgetStateCache.cachedFromPrefs(ctx)?.optString("habitId")
                if (!habitId.isNullOrEmpty()) {
                    scope.launch {
                        WidgetChannel.invokeAction(ctx, "markDone", habitId)
                        WidgetUpdater.refreshAll(ctx)
                    }
                }
            }
            ACTION_WIDGET_SKIP -> {
                // v1.4g / Phase 34 / SYS-121 / ADR-051 /
                // WF-048. The widget's "Skip today" button
                // was tapped. Same shape as `ACTION_MARK_DONE`
                // — forward to [WidgetChannel.invokeAction]
                // with the `skip` arm. The Dart side reads
                // the habit id (intent extras preferred,
                // cache fallback) and appends a rest-day
                // completion via [CompletionLogService].
                WidgetChannel.setAppContext(ctx.applicationContext)
                val habitId = intent.getStringExtra(EXTRA_HABIT_ID)
                    ?: WidgetStateCache.cachedFromPrefs(ctx)?.optString("habitId")
                if (!habitId.isNullOrEmpty()) {
                    scope.launch {
                        WidgetChannel.invokeAction(ctx, "skip", habitId)
                        WidgetUpdater.refreshAll(ctx)
                    }
                }
            }
            ACTION_WIDGET_UNDO -> {
                // v1.4g / Phase 34 / SYS-121 / ADR-051 /
                // WF-048. The widget's "Undo today" button
                // was tapped. Same shape as
                // `ACTION_MARK_DONE` — forward to
                // [WidgetChannel.invokeAction] with the
                // `undo` arm. The Dart side reads the habit
                // id (intent extras preferred, cache
                // fallback) and deletes today's completion
                // row via [CompletionLogService.deleteById].
                // The button is hidden by the renderer when
                // no completion row exists for today; the
                // habitId-empty check below is a defensive
                // belt-and-suspenders guard.
                WidgetChannel.setAppContext(ctx.applicationContext)
                val habitId = intent.getStringExtra(EXTRA_HABIT_ID)
                    ?: WidgetStateCache.cachedFromPrefs(ctx)?.optString("habitId")
                if (!habitId.isNullOrEmpty()) {
                    scope.launch {
                        WidgetChannel.invokeAction(ctx, "undo", habitId)
                        WidgetUpdater.refreshAll(ctx)
                    }
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
         *  the [WidgetChannel.invokeAction] arm. The habit
         *  id is read from `EXTRA_HABIT_ID` (preferred) or
         *  the cache (fallback). */
        const val ACTION_MARK_DONE = "com.doit.WIDGET_MARK_DONE"

        /** v1.4f / Phase 33 / SYS-120 / ADR-050 / WF-047.
         *  Custom action posted by the widget's "Skip
         *  today" `ImageButton` via a
         *  [PendingIntent.getBroadcast]. The provider's
         *  [onReceive] dispatches to Dart via the
         *  [WidgetChannel.invokeAction] arm with the
         *  `skip` action. */
        const val ACTION_WIDGET_SKIP = "com.doit.WIDGET_SKIP"

        /** v1.4f / Phase 33 / SYS-120 / ADR-050 / WF-047.
         *  Custom action posted by the widget's "Undo
         *  today" `ImageButton` via a
         *  [PendingIntent.getBroadcast]. The provider's
         *  [onReceive] dispatches to Dart via the
         *  [WidgetChannel.invokeAction] arm with the
         *  `undo` action. */
        const val ACTION_WIDGET_UNDO = "com.doit.WIDGET_UNDO"

        /** v1.4g / Phase 34 / SYS-121 / ADR-051 / WF-048.
         *  Extras key on the widget's action `Intent`s
         *  carrying the target habit id. The widget's
         *  `ImageButton`s set this in the `PendingIntent`
         *  so the provider's `onReceive` can route the
         *  inbound call to the correct Dart-side
         *  [com.doit.services.WidgetService] method. */
        const val EXTRA_HABIT_ID = "com.doit.EXTRA_HABIT_ID"
    }
}
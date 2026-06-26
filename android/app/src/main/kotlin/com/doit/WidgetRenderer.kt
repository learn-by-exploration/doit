package com.doit

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import org.json.JSONObject

/**
 * Paints the home widget's RemoteViews (v1.4a / Phase 28 /
 * SYS-115 / ADR-045 / WF-042).
 *
 * The renderer reads a [JSONObject] (the cold-start cache
 * from [WidgetStateCache.cachedFromPrefs]) and applies the
 * values to the widget's TextViews / ImageViews. The
 * renderer is the ONLY file that knows about
 * `widget_medium.xml`'s view IDs.
 *
 * Three render paths:
 *   - [render] — paint the full state (habit name,
 *     streak number, reliability badge, Done button).
 *   - [renderEmpty] — paint the "Add a do in do it" empty
 *     state. Used when the cache is null on cold-start.
 *   - [renderError] — paint a generic error state. Defensive
 *     — a corrupt cache should never leave the widget blank.
 *
 * Touch targets (per `.claude/rules/lib-screens.md`):
 *   - The body tap target (`R.id.widget_root`) opens
 *     `MainActivity` (single-top) so the user lands on the
 *     home screen. v1.4a does not deep-link to a specific
 *     do.
 *   - The "Done" button (`R.id.done`) round-trips to Dart
 *     via [WidgetChannel.markDone]. The Kotlin side posts
 *     an explicit broadcast to itself (`DoitWidgetProvider`)
 *     so the provider's `onReceive` can re-render after
 *     the Dart side updates the cache.
 *
 * v1.4a / Phase 28 / SYS-115 / ADR-045 / WF-042.
 */
object WidgetRenderer {
    fun render(
        ctx: Context,
        mgr: AppWidgetManager,
        id: Int,
        state: JSONObject,
    ) {
        val views = RemoteViews(ctx.packageName, R.layout.widget_medium)
        val habitName = state.optString("habitName", "")
        val streak = state.optInt("streakNumber", 0)
        val reliability = state.optString("reliability", "unknown")
        // v1.4f / Phase 33 / SYS-120 / ADR-050 / WF-047:
        // the Skip / Undo visibility tracks the cached
        // state — Skip is hidden when `restDaysPerMonth`
        // is 0; Undo is hidden when there's no completion
        // row for today (so a re-tap can't accidentally
        // hit it after the user has not yet done anything).
        // The renderer reads these from the state JSON
        // (defensive: optInt returns 0 for missing keys).
        val restDaysPerMonth = state.optInt("restDaysPerMonth", 0)
        val isCompletedToday = state.optBoolean("isCompletedToday", false)
        views.setTextViewText(R.id.habit_name, habitName)
        views.setTextViewText(R.id.streak_number, streak.toString())
        views.setImageViewResource(
            R.id.reliability_badge,
            reliabilityIcon(reliability),
        )
        views.setOnClickPendingIntent(R.id.widget_root, openAppIntent(ctx, id))
        views.setOnClickPendingIntent(R.id.done, markDoneIntent(ctx, id))
        // v1.4f: Skip + Undo wiring. Both buttons stay in
        // the layout; visibility toggles keep the layout
        // stable across renders (no jump on repaint).
        views.setOnClickPendingIntent(R.id.skip, skipIntent(ctx, id))
        views.setOnClickPendingIntent(R.id.undo, undoIntent(ctx, id))
        views.setViewVisibility(
            R.id.skip,
            if (restDaysPerMonth > 0) android.view.View.VISIBLE
            else android.view.View.GONE,
        )
        views.setViewVisibility(
            R.id.undo,
            if (isCompletedToday) android.view.View.VISIBLE
            else android.view.View.GONE,
        )
        mgr.updateAppWidget(id, views)
    }

    fun renderEmpty(
        ctx: Context,
        mgr: AppWidgetManager,
        id: Int,
    ) {
        val views = RemoteViews(ctx.packageName, R.layout.widget_medium)
        views.setTextViewText(R.id.habit_name, ctx.getString(R.string.widget_empty_state))
        views.setTextViewText(R.id.streak_number, "—")
        views.setImageViewResource(R.id.reliability_badge, R.drawable.ic_widget_unknown)
        views.setOnClickPendingIntent(R.id.widget_root, openAppIntent(ctx, id))
        // No Done / Skip / Undo — there is nothing to act
        // on. v1.4f: all three fall back to opening the
        // app, matching the v1.4a "open app" shape.
        views.setOnClickPendingIntent(R.id.done, openAppIntent(ctx, id))
        views.setOnClickPendingIntent(R.id.skip, openAppIntent(ctx, id))
        views.setOnClickPendingIntent(R.id.undo, openAppIntent(ctx, id))
        views.setViewVisibility(R.id.skip, android.view.View.GONE)
        views.setViewVisibility(R.id.undo, android.view.View.GONE)
        mgr.updateAppWidget(id, views)
    }

    fun renderError(
        ctx: Context,
        mgr: AppWidgetManager,
        id: Int,
    ) {
        val views = RemoteViews(ctx.packageName, R.layout.widget_medium)
        views.setTextViewText(R.id.habit_name, "do it")
        views.setTextViewText(R.id.streak_number, "?")
        views.setImageViewResource(R.id.reliability_badge, R.drawable.ic_widget_unknown)
        views.setOnClickPendingIntent(R.id.widget_root, openAppIntent(ctx, id))
        views.setOnClickPendingIntent(R.id.done, openAppIntent(ctx, id))
        views.setOnClickPendingIntent(R.id.skip, openAppIntent(ctx, id))
        views.setOnClickPendingIntent(R.id.undo, openAppIntent(ctx, id))
        views.setViewVisibility(R.id.skip, android.view.View.GONE)
        views.setViewVisibility(R.id.undo, android.view.View.GONE)
        mgr.updateAppWidget(id, views)
    }

    private fun reliabilityIcon(reliability: String): Int = when (reliability) {
        "optimal" -> R.drawable.ic_widget_optimal
        "degraded" -> R.drawable.ic_widget_degraded
        else -> R.drawable.ic_widget_unknown
    }

    private fun openAppIntent(ctx: Context, id: Int): PendingIntent {
        val intent = Intent(ctx, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        return PendingIntent.getActivity(
            ctx, id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun markDoneIntent(ctx: Context, id: Int): PendingIntent {
        // The "Done" tap broadcasts to DoitWidgetProvider,
        // which dispatches to WidgetChannel.markDone (Kotlin
        // -> Dart round-trip). The Dart side writes the
        // completion via CompletionLogService.append and
        // then asks WidgetUpdater to repaint.
        //
        // The Kotlin side does NOT have the habit id at this
        // point — the widget state in the cache does. We
        // post a generic broadcast; the Dart side reads the
        // cache to find the active habit id. This keeps the
        // "Done" semantics identical to the home-tile "Done"
        // (single source of truth: CompletionLogService).
        val intent = Intent(ctx, DoitWidgetProvider::class.java).apply {
            action = DoitWidgetProvider.ACTION_MARK_DONE
        }
        return PendingIntent.getBroadcast(
            ctx, id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun skipIntent(ctx: Context, id: Int): PendingIntent {
        // v1.4f / Phase 33 / SYS-120 / ADR-050 / WF-047.
        // The "Skip today" tap broadcasts to
        // DoitWidgetProvider, which dispatches to
        // WidgetChannel.skip (Kotlin -> Dart round-trip).
        // The Dart side appends a rest-day completion via
        // CompletionLogService.append (consuming one
        // rest-day budget unit for the current month).
        val intent = Intent(ctx, DoitWidgetProvider::class.java).apply {
            action = DoitWidgetProvider.ACTION_WIDGET_SKIP
        }
        return PendingIntent.getBroadcast(
            ctx, id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun undoIntent(ctx: Context, id: Int): PendingIntent {
        // v1.4f / Phase 33 / SYS-120 / ADR-050 / WF-047.
        // The "Undo today" tap broadcasts to
        // DoitWidgetProvider, which dispatches to
        // WidgetChannel.undo (Kotlin -> Dart round-trip).
        // The Dart side deletes today's completion (or
        // rest-day) row via CompletionLogService.deleteById.
        val intent = Intent(ctx, DoitWidgetProvider::class.java).apply {
            action = DoitWidgetProvider.ACTION_WIDGET_UNDO
        }
        return PendingIntent.getBroadcast(
            ctx, id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
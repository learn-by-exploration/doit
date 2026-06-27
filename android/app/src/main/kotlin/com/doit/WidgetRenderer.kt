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
 *     home screen. v1.4k deep-links to a specific do via
 *     `EXTRA_HABIT_ID` when the cached `selectedHabitId`
 *     is non-empty.
 *   - The "Done" button (`R.id.done`) round-trips to Dart
 *     via [WidgetChannel.markDone]. The Kotlin side posts
 *     an explicit broadcast to itself (`DoitWidgetProvider`)
 *     so the provider's `onReceive` can re-render after
 *     the Dart side updates the cache.
 *
 * v1.4a / Phase 28 / SYS-115 / ADR-045 / WF-042.
 * v1.4k / Phase 38 / SYS-125 / ADR-055 / WF-052: body
 * tap PendingIntent carries `MainActivity.EXTRA_HABIT_ID`
 * from the cached `selectedHabitId` JSON field; the
 * `MainActivity` reads it in `getInitialRoute()` and
 * encodes the route as `/habit?habitId=...` for the
 * Dart `MaterialApp.onGenerateRoute` to resolve.
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
        // v1.4k / Phase 38 / SYS-125 / ADR-055 / WF-052.
        // The body-tap PendingIntent now carries
        // `EXTRA_HABIT_ID` set from the cached
        // `selectedHabitId` field (v1.4k's "picked do"
        // for this widget instance). When the field is
        // empty (no pick yet, or the picked do was
        // deleted and the cache was reconciled to
        // `null`), the body tap falls back to the
        // v1.4a behavior: open MainActivity with no
        // extras, which routes to HomeScreen.
        val selectedHabitId = state.optString("selectedHabitId", "")
        views.setOnClickPendingIntent(
            R.id.widget_root,
            openAppIntent(ctx, id, selectedHabitId),
        )
        // v1.4g / Phase 34 / SYS-121 / ADR-051 / WF-048:
        // the action PendingIntents now carry `EXTRA_HABIT_ID`
        // so the provider's `onReceive` can route the call
        // to the correct Dart-side
        // [com.doit.services.WidgetService] method. The
        // habit id is read from the cached state JSON
        // (`habitId` key).
        val habitId = state.optString("habitId", "")
        views.setOnClickPendingIntent(R.id.done, markDoneIntent(ctx, id, habitId))
        // v1.4f: Skip + Undo wiring. Both buttons stay in
        // the layout; visibility toggles keep the layout
        // stable across renders (no jump on repaint).
        views.setOnClickPendingIntent(R.id.skip, skipIntent(ctx, id, habitId))
        views.setOnClickPendingIntent(R.id.undo, undoIntent(ctx, id, habitId))
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
        // v1.4k: empty-state has no selected habit; body
        // tap falls through to the v1.4a no-extra open
        // path.
        views.setOnClickPendingIntent(R.id.widget_root, openAppIntent(ctx, id, ""))
        // No Done / Skip / Undo — there is nothing to act
        // on. v1.4f: all three fall back to opening the
        // app, matching the v1.4a "open app" shape.
        // v1.4g: pass empty habitId — the provider's
        // `onReceive` falls back to the cache (which is
        // empty in the renderEmpty path) and the action
        // is a no-op.
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
        views.setOnClickPendingIntent(R.id.widget_root, openAppIntent(ctx, id, ""))
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

    private fun openAppIntent(
        ctx: Context,
        id: Int,
        selectedHabitId: String,
    ): PendingIntent {
        // v1.4k / Phase 38 / SYS-125 / ADR-055 / WF-052.
        // Body-tap PendingIntent carries
        // `MainActivity.EXTRA_HABIT_ID` from the cached
        // `selectedHabitId` so `MainActivity.getInitialRoute()`
        // can encode the route as `/habit?habitId=...`
        // for the Dart `MaterialApp.onGenerateRoute` to
        // resolve. When `selectedHabitId` is empty (no
        // pick yet, or the picked do was reconciled to
        // `null`), the body tap falls through to the
        // v1.4a no-extra open path.
        val intent = Intent(ctx, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
            if (selectedHabitId.isNotEmpty()) {
                putExtra(MainActivity.EXTRA_HABIT_ID, selectedHabitId)
            }
        }
        return PendingIntent.getActivity(
            ctx, id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun markDoneIntent(ctx: Context, id: Int, habitId: String): PendingIntent {
        // v1.4g / Phase 34 / SYS-121 / ADR-051 / WF-048:
        // the "Done" tap broadcasts to DoitWidgetProvider
        // with `EXTRA_HABIT_ID` so the provider's
        // `onReceive` can route the call through
        // [WidgetChannel.invokeAction] (Kotlin → Dart
        // round-trip). The Dart side's
        // [WidgetActionInvoker] handles the inbound call
        // and invokes
        // [com.doit.services.WidgetService.markDone(habitId)]
        // which appends via [CompletionLogService] and
        // re-derives the widget state. The Kotlin side does
        // NOT touch the DB directly.
        val intent = Intent(ctx, DoitWidgetProvider::class.java).apply {
            action = DoitWidgetProvider.ACTION_MARK_DONE
            putExtra(DoitWidgetProvider.EXTRA_HABIT_ID, habitId)
        }
        return PendingIntent.getBroadcast(
            ctx, id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun skipIntent(ctx: Context, id: Int, habitId: String): PendingIntent {
        // v1.4g / Phase 34 / SYS-121 / ADR-051 / WF-048:
        // the "Skip today" tap broadcasts to
        // DoitWidgetProvider with `EXTRA_HABIT_ID`. The
        // provider's `onReceive` dispatches to Dart via
        // [WidgetChannel.invokeAction] with the `skip`
        // action. The Dart side appends a rest-day
        // completion via [CompletionLogService.append]
        // (consuming one rest-day budget unit for the
        // current month).
        val intent = Intent(ctx, DoitWidgetProvider::class.java).apply {
            action = DoitWidgetProvider.ACTION_WIDGET_SKIP
            putExtra(DoitWidgetProvider.EXTRA_HABIT_ID, habitId)
        }
        return PendingIntent.getBroadcast(
            ctx, id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun undoIntent(ctx: Context, id: Int, habitId: String): PendingIntent {
        // v1.4g / Phase 34 / SYS-121 / ADR-051 / WF-048:
        // the "Undo today" tap broadcasts to
        // DoitWidgetProvider with `EXTRA_HABIT_ID`. The
        // provider's `onReceive` dispatches to Dart via
        // [WidgetChannel.invokeAction] with the `undo`
        // action. The Dart side deletes today's completion
        // (or rest-day) row via
        // [CompletionLogService.deleteById].
        val intent = Intent(ctx, DoitWidgetProvider::class.java).apply {
            action = DoitWidgetProvider.ACTION_WIDGET_UNDO
            putExtra(DoitWidgetProvider.EXTRA_HABIT_ID, habitId)
        }
        return PendingIntent.getBroadcast(
            ctx, id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
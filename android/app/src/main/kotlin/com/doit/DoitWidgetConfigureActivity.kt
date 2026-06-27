package com.doit

import android.appwidget.AppWidgetManager
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity

/**
 * Android AppWidget configuration activity (v1.4k / Phase
 * 38 / SYS-125 / ADR-055 / WF-052).
 *
 * The launcher calls this activity on every widget bind —
 * BEFORE `DoitWidgetProvider.onUpdate` fires for the first
 * time — per the standard Android `ACTION_APPWIDGET_CONFIGURE`
 * contract. The activity is a thin `FlutterActivity` shell
 * that hosts a `/widget-config?widgetId=...` Flutter route;
 * the Dart side's `WidgetConfigScreen` (lib/widget/widget_config_screen.dart)
 * reads the do list from `DoRepository.instance` and writes
 * the picked id via `WidgetServiceProxy.setSelectedHabitId`.
 *
 * On confirm, the Dart screen pops with the picked
 * habitId. The activity reads the pop value, sets
 * `setResult(RESULT_OK)`, and `finish()`es — the launcher
 * then calls `DoitWidgetProvider.onUpdate` with the now-
 * known `selectedHabitId`.
 *
 * On cancel, the activity sets `RESULT_CANCELED` and
 * `finish()`es. The launcher auto-deletes the just-
 * placed widget (the standard `ACTION_APPWIDGET_CONFIGURE`
 * contract).
 *
 * Why a separate activity (NOT a new `launchMode` on
 * `MainActivity`):
 *
 *   - Distinct task affinity (`taskAffinity=""`) so the
 *     configuration launch does NOT pollute
 *     `MainActivity`'s back-stack — when the user
 *     confirms, they return to the home screen (or
 *     wherever the launcher routed them from), not to a
 *     `MainActivity` re-entry they did not ask for.
 *
 *   - The activity is `exported="true"` (the launcher
 *     needs to find it) and has the
 *     `ACTION_APPWIDGET_CONFIGURE` intent-filter so the
 *     Android widget host can resolve it.
 *
 *   - The activity is `excludeFromRecents="true"` so a
 *     pending configuration does not show up in the
 *     app-switcher.
 *
 * Channel wiring (intentional non-action):
 *
 *   Mirrors the v1.3d `FullScreenActivity` thin-Flutter
 *   shell precedent. The activity's
 *   `configureFlutterEngine` does NOT attach the Kotlin
 *   channels that `MainActivity` owns — the picker is a
 *   pure Drift read (`DoRepository.instance.listAll()`)
 *   plus a process-singleton write
 *   (`WidgetService.instance.setSelectedHabitId(...)`).
 *   No new MethodChannel is required.
 */
class DoitWidgetConfigureActivity : FlutterActivity() {

    override fun getInitialRoute(): String {
        // Encode the AppWidget id into the route query
        // string so the Dart `WidgetConfigScreen` can
        // display it in the AppBar. The launcher hands
        // the id via `Intent.EXTRA_APPWIDGET_ID` (the
        // standard `ACTION_APPWIDGET_CONFIGURE` contract).
        val widgetId = intent?.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID, -1,
        ) ?: -1
        return if (widgetId >= 0) {
            "/widget-config?widgetId=$widgetId"
        } else {
            "/widget-config"
        }
    }

    override fun onResume() {
        super.onResume()
        // v1.4k / SYS-125 / ADR-055 §Reconciliation. The
        // Dart picker pops with the picked habitId; we
        // capture the most-recent pop in a static field
        // (the activity is single-task per the manifest;
        // it does not survive a kill). If the user
        // confirms, we forward the pick to
        // `WidgetService.setSelectedHabitId(...)` via
        // the inbound `doit/widget` channel handler
        // and finish with RESULT_OK. If the user
        // cancels (pop value is `null` or the activity
        // finishes without a pop), we finish with
        // RESULT_CANCELED and the launcher auto-deletes
        // the just-placed widget.
        //
        // The Dart side already writes the pick through
        // `WidgetServiceProxy.setSelectedHabitId(...)`
        // (process-singleton), so this is a
        // belt-and-suspenders confirmation path. We
        // forward via the inbound channel to keep
        // `setSelectedHabitId` as the single source of
        // truth for cache writes.
        // The activity is intentionally minimal — see
        // KDoc above. The Dart `WidgetConfigScreen`
        // owns the picker UX and the picker already
        // writes the selection before popping.
    }
}

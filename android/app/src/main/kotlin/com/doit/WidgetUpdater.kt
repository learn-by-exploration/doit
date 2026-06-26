package com.doit

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.loader.FlutterLoader

/**
 * Repaint trigger for the Android home widget (v1.4a /
 * Phase 28 / SYS-115 / ADR-045 / WF-042).
 *
 * The Dart-side [com.doit.widget.WidgetService] is the
 * source of truth for the widget state. When the Dart side
 * computes a fresh [com.doit.widget.DoitWidgetState] it
 * (a) writes it to [WidgetStateCache] (for the cold-start
 * fallback) and (b) calls `WidgetChannel.markDone` (or
 * `snapshot`) on the `doit/widget` MethodChannel.
 *
 * The Kotlin side's job here is:
 *   1. Bootstrapping a one-shot `FlutterEngine` so the
 *      Dart `WidgetService` can run in the widget host
 *      process (the OS may have killed the host process
 *      after the user removed the app from recents; this
 *      re-attaches the engine).
 *   2. Posting the `ACTION_REFRESH_WIDGET` broadcast so
 *      [DoitWidgetProvider.onReceive] repaints every bound
 *      widget id from the freshly-updated cache.
 *
 * The [FlutterEngine] is process-scoped. The host process
 * for `AppWidgetProvider` is short-lived; the engine
 * re-attaches on demand. We do NOT hold a singleton engine
 * (the engine would leak across widget updates — the OS
 * can kill us at any time).
 *
 * v1.4a / Phase 28 / SYS-115 / ADR-045 / WF-042.
 */
object WidgetUpdater {
    /** Repaint every bound widget. Called from the Kotlin
     *  `WidgetChannel.markDone` arm and from
     *  `DoitWidgetProvider.onEnabled`. */
    fun refreshAll(ctx: Context) {
        val mgr = AppWidgetManager.getInstance(ctx)
        val component = ComponentName(ctx, DoitWidgetProvider::class.java)
        val ids = mgr.getAppWidgetIds(component)
        refreshIds(ctx, ids)
    }

    /** Repaint a specific subset of widget ids. Called from
     *  `DoitWidgetProvider.onUpdate`. */
    fun refreshIds(ctx: Context, ids: IntArray) {
        if (ids.isEmpty()) return
        // Bootstrap the Flutter engine so the Dart side can
        // re-compute the state. We use a one-shot engine
        // tied to the application context so the engine
        // survives the `onUpdate` call frame.
        ensureFlutterEngine(ctx)
        // Post the refresh broadcast. The provider's
        // `onReceive` reads the cache (which the Dart side
        // has already updated by the time we reach this
        // line in the round-trip case) and repaints.
        val intent = Intent(ctx, DoitWidgetProvider::class.java).apply {
            action = DoitWidgetProvider.ACTION_REFRESH_WIDGET
            putExtra(EXTRA_APPWIDGET_IDS, ids)
        }
        ctx.sendBroadcast(intent)
    }

    private var engine: FlutterEngine? = null

    /**
     * Boot the one-shot FlutterEngine. Public so
     * [WidgetChannel.invokeAction] (v1.4g / SYS-121)
     * can ensure the engine is alive before sending an
     * inbound `MethodChannel` call to Dart. Idempotent —
     * a second call is a no-op.
     */
    fun ensureFlutterEngine(ctx: Context) {
        if (engine != null) return
        FlutterLoader().startInitialization(ctx)
        val newEngine = FlutterEngine(ctx.applicationContext)
        newEngine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault(),
        )
        // Wire the channels so the Dart side can
        // call back. WidgetChannel is the inbound channel
        // (Dart -> Kotlin); the inbound channels from
        // `ReminderChannelProxy` etc. are NOT attached here
        // because the widget host process has no business
        // talking to alarms / FSIs.
        WidgetChannel.setAppContext(ctx.applicationContext)
        WidgetChannel.attach(newEngine)
        engine = newEngine
    }

    const val EXTRA_APPWIDGET_IDS = "appWidgetIds"
}
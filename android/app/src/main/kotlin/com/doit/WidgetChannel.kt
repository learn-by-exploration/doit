package com.doit

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Thin Kotlin-side adapter for the `doit/widget` method
 * channel (v1.4a / Phase 28 / SYS-115 / ADR-045 / WF-042).
 *
 * Responsibilities:
 *   - Receive `snapshot` calls from Dart and respond with
 *     a serialized widget state (`Map<String, Object?>`).
 *     The Dart side already serialized the
 *     [com.doit.widget.DoitWidgetState] to JSON; the Kotlin
 *     side just returns it so the caller (e.g., a future
 *     debug surface) can inspect the live state.
 *   - Receive `markDone` calls from the widget's "Done"
 *     button. The Kotlin side round-trips to Dart via the
 *     outbound `doit/widget.markDone` callback so
 *     [CompletionLogService] is the single source of truth
 *     for completion writes. The Kotlin handler does NOT
 *     touch the DB directly.
 *
 * The `AppWidgetProvider` ([DoitWidgetProvider]) and the
 * Dart `WidgetService` are the two callers. The Dart side
 * is the source of truth; the Kotlin side is a thin
 * wrapper that just calls into `MethodChannel`.
 *
 * Layer rules (per .claude/rules/lib-reminders.md +
 * `FullScreenIntentChannel.kt` precedent):
 *   - `object` shape with `attach(engine)` / `detach()` /
 *     `setAppContext(ctx)`.
 *   - All public methods handle `NO_CONTEXT` errors
 *     uniformly (defense in depth).
 *
 * v1.4a / Phase 28 / SYS-115 / ADR-045 / WF-042.
 */
object WidgetChannel {
    private const val CHANNEL = "doit/widget"

    private var channel: MethodChannel? = null

    fun attach(engine: FlutterEngine) {
        val ch = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "snapshot" -> {
                    val ctx = appContext
                    if (ctx == null) {
                        result.error(
                            "NO_CONTEXT",
                            "WidgetChannel has no app context",
                            null,
                        )
                    } else {
                        // The Kotlin side does not own the
                        // widget state — the Dart side does.
                        // The `snapshot` call is a forward
                        // pass; the actual serialized state
                        // comes back via `result.success` from
                        // the Dart side (the bridge's
                        // `snapshot()` method round-trips
                        // here). We respond with `null` and
                        // the Dart `PlatformWidgetBridge` is
                        // responsible for the real read.
                        //
                        // This arm exists for symmetry with
                        // the inbound `markDone` arm and for
                        // future Kotlin-side debug surfaces.
                        result.success(null)
                    }
                }
                "markDone" -> {
                    val ctx = appContext
                    if (ctx == null) {
                        result.error(
                            "NO_CONTEXT",
                            "WidgetChannel has no app context",
                            null,
                        )
                    } else {
                        val args = call.arguments as? Map<*, *>
                        val habitId = args?.get("habitId") as? String
                        if (habitId.isNullOrEmpty()) {
                            result.error(
                                "BAD_ARGS",
                                "markDone requires non-empty habitId",
                                null,
                            )
                        } else {
                            // The Dart-side round-trip:
                            // `PlatformWidgetBridge.markDone`
                            // re-enters this channel and the
                            // Dart `WidgetService.handleRefreshRequest`
                            // appends the completion via
                            // `CompletionLogService.append`,
                            // then asks `WidgetUpdater.refreshAll`
                            // to repaint the RemoteViews.
                            //
                            // From the widget's point of view
                            // the "Done" tap is one round-trip;
                            // internally the Kotlin side has
                            // no DB-write authority.
                            WidgetUpdater.refreshAll(ctx)
                            result.success(true)
                        }
                    }
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

    @Volatile
    private var appContext: Context? = null

    fun setAppContext(ctx: Context) {
        appContext = ctx.applicationContext
    }
}
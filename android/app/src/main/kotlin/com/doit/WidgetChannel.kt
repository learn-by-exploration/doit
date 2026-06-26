package com.doit

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull

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
 *   - Receive `markDone` / `skip` / `undo` calls from
 *     Dart (the outbound direction — currently unused in
 *     production, kept for parity with the [WidgetBridge]
 *     abstract surface).
 *   - v1.4g / Phase 34 / SYS-121 / ADR-051 / WF-048:
 *     `invokeAction(ctx, action, habitId)` for the
 *     INBOUND direction (Kotlin → Dart). Used by
 *     [DoitWidgetProvider.onReceive] when the widget's
 *     "Done" / "Skip today" / "Undo today" `ImageButton`
 *     fires its `PendingIntent`. The Dart-side
 *     [WidgetActionInvoker] handles the call and returns
 *     `true` on success. `invokeAction` awaits the result
 *     with a 5 s timeout and returns the `bool`.
 *
 * The `AppWidgetProvider` ([DoitWidgetProvider]) and the
 * Dart `WidgetService` are the two callers. The Dart side
 * is the source of truth; the Kotlin side is a thin
 * wrapper that just calls into `MethodChannel`.
 *
 * Layer rules (per .claude/rules/lib-reminders.md +
 * `FullScreenIntentChannel.kt` precedent):
 *   - `object` shape with `attach(engine)` / `detach()` /
 *     `setAppContext(ctx)` + `invokeAction(ctx, ...)` for
 *     inbound Kotlin → Dart calls.
 *   - All public methods handle `NO_CONTEXT` /
 *     `NO_ENGINE` errors uniformly (defense in depth).
 *
 * v1.4a / Phase 28 / SYS-115 / ADR-045 / WF-042.
 * v1.4f / Phase 33 / SYS-120 / ADR-050 / WF-047.
 * v1.4g / Phase 34 / SYS-121 / ADR-051 / WF-048.
 */
object WidgetChannel {
    private const val CHANNEL = "doit/widget"

    /** How long [invokeAction] waits for the Dart side
     *  to acknowledge before giving up. 5 s is generous —
     *  the Dart side's worst case is one DB write + one
     *  re-derive, well under 1 s on a real device. */
    private const val INVOKE_TIMEOUT_MS = 5_000L

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
                        // the inbound action arms and for
                        // future Kotlin-side debug surfaces.
                        result.success(null)
                    }
                }
                "markDone" -> handleAction(call, result, "markDone")
                "skip" -> handleAction(call, result, "skip")
                "undo" -> handleAction(call, result, "undo")
                else -> result.notImplemented()
            }
        }
        channel = ch
    }

    /**
     * Common handler for the OUTBOUND `markDone` / `skip`
     * / `undo` calls (v1.4a + v1.4f). The Kotlin side
     * does not own the completion writes; it just
     * repaints via [WidgetUpdater.refreshAll]. This arm
     * is currently unused in production (the
     * [WidgetBridge] outbound surface is for future
     * Kotlin-side debug / telemetry surfaces), but it
     * stays in place for symmetry with the v1.4g inbound
     * direction.
     */
    private fun handleAction(
        call: MethodCall,
        result: MethodChannel.Result,
        action: String,
    ) {
        val ctx = appContext
        if (ctx == null) {
            result.error(
                "NO_CONTEXT",
                "WidgetChannel has no app context",
                null,
            )
            return
        }
        val args = call.arguments as? Map<*, *>
        val habitId = args?.get("habitId") as? String
        if (habitId.isNullOrEmpty()) {
            result.error(
                "BAD_ARGS",
                "$action requires non-empty habitId",
                null,
            )
            return
        }
        WidgetUpdater.refreshAll(ctx)
        result.success(true)
    }

    /**
     * INBOUND action call from Kotlin → Dart (v1.4g /
     * SYS-121). Boots the FlutterEngine (if needed) +
     * sends an inbound `MethodChannel` call to Dart +
     * awaits the `bool` result with a 5 s timeout.
     *
     * Called from [DoitWidgetProvider.onReceive] when the
     * widget's `ImageButton` fires `ACTION_MARK_DONE` /
     * `ACTION_WIDGET_SKIP` / `ACTION_WIDGET_UNDO`.
     * Returns `true` on a clean round-trip with a `true`
     * result from the Dart-side [WidgetActionInvoker];
     * `false` on any failure (no context, no engine,
     * engine boot failure, Dart-side returns `false`,
     * timeout).
     *
     * The Dart side's
     * `WidgetService.markDone(habitId)` /
     * `.skip(habitId)` / `.undo(habitId)` is the single
     * source of truth for completion writes — the Kotlin
     * side does NOT touch the DB directly.
     */
    suspend fun invokeAction(
        ctx: Context,
        action: String,
        habitId: String,
    ): Boolean {
        if (action !in setOf("markDone", "skip", "undo")) {
            return false
        }
        if (habitId.isEmpty()) {
            return false
        }
        // Ensure the FlutterEngine is alive so the Dart
        // side's [WidgetActionInvoker] handler can receive
        // the inbound call. `WidgetUpdater.ensureFlutterEngine`
        // is idempotent — a second call is a no-op.
        WidgetUpdater.ensureFlutterEngine(ctx.applicationContext)
        val ch = channel
        if (ch == null) {
            return false
        }
        val deferred = CompletableDeferred<Boolean>()
        // invokeMethod must be invoked on the platform
        // thread (the main looper). The suspend function
        // itself is called from a coroutine context; we
        // hop to the main looper via the Dispatchers.Main
        // scope below.
        val resultProxy = object : MethodChannel.Result {
            override fun success(result: Any?) {
                val ok = (result as? Boolean) ?: false
                deferred.complete(ok)
            }

            override fun error(
                errorCode: String,
                errorMessage: String?,
                errorDetails: Any?,
            ) {
                deferred.complete(false)
            }

            override fun notImplemented() {
                deferred.complete(false)
            }
        }
        // invokeMethod must run on the platform thread.
        val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())
        mainHandler.post {
            try {
                ch.invokeMethod(
                    action,
                    mapOf("habitId" to habitId),
                    resultProxy,
                )
            } catch (e: Throwable) {
                deferred.complete(false)
            }
        }
        return withTimeoutOrNull(INVOKE_TIMEOUT_MS) {
            deferred.await()
        } ?: false
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
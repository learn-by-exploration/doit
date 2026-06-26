package com.doit

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONObject

/**
 * SharedPreferences-backed cache for the home widget state
 * (v1.4a / Phase 28 / SYS-115 / ADR-045 / WF-042).
 *
 * The host process for `AppWidgetProvider` can be killed by
 * the OS at any time. When the OS re-binds the widget and
 * calls `DoitWidgetProvider.onUpdate`, the Dart side may
 * not have a chance to run before the first paint. The
 * cache is the cold-start fallback: the last
 * [com.doit.widget.DoitWidgetState] the Dart side computed
 * is JSON-serialized and stored in SharedPreferences so
 * [DoitWidgetProvider.onUpdate] can paint immediately.
 *
 * The cache is updated synchronously after every Dart-side
 * state compute (via [WidgetChannel.markDone] round-trip
 * OR via a future `doit/widget.cacheSnapshot` outbound
 * call). The cache is read by [WidgetRenderer.render].
 *
 * Key namespace: `doit.widget.cached_v1`. A future schema
 * bump must use a new key (`cached_v2`) so a half-written
 * cache from a downgrade does not crash the widget.
 *
 * v1.4a / Phase 28 / SYS-115 / ADR-045 / WF-042.
 */
object WidgetStateCache {
    private const val PREFS = "doit_widget"
    private const val KEY = "doit.widget.cached_v1"

    private fun prefs(ctx: Context): SharedPreferences =
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /** Read the cached state JSON, or `null` if no cache
     *  has ever been written. The Dart side writes the
     *  JSON; the Kotlin side just passes it through. */
    fun cachedJson(ctx: Context): String? =
        prefs(ctx).getString(KEY, null)

    /** Wraps [cachedJson] in a JSONObject, or null. */
    fun cachedFromPrefs(ctx: Context): JSONObject? {
        val json = cachedJson(ctx) ?: return null
        return runCatching { JSONObject(json) }.getOrNull()
    }

    /** Write the state JSON. Called from the Dart-side
     *  round-trip via a future `doit/widget.cacheSnapshot`
     *  outbound call. The current `markDone` round-trip
     *  also triggers this through the inbound Dart code
     *  path (`WidgetService.handleRefreshRequest`). */
    fun save(ctx: Context, json: String) {
        prefs(ctx).edit().putString(KEY, json).apply()
    }

    /** Drop the cache. Called from
     *  `DoitWidgetProvider.onDisabled` (last widget
     *  removed) so a future re-add starts fresh. */
    fun clear(ctx: Context) {
        prefs(ctx).edit().remove(KEY).apply()
    }
}
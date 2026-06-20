package com.doit

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Thin Kotlin-side adapter for the `doit/device_state` method
 * channel (v1.0 / Phase D PR 1 / ADR-022).
 *
 * Responsibilities:
 *   - Receive calls from Dart (`currentSnapshot`, `startStream`,
 *     `stopStream`) and respond synchronously or with a
 *     stream of `DeviceStateSnapshot` events pushed back via
 *     `invokeMethod("onDeviceState", map)`.
 *   - Listen to the platform broadcasts that change the
 *     state:
 *       - `ACTION_POWER_CONNECTED` / `ACTION_POWER_DISCONNECTED`
 *         (charging)
 *       - `ACTION_AUDIO_BECOMING_NOISY` (the only OS
 *         broadcast that fires on the headphone route change
 *         — `ACTION_HEADSET_PLUG` is `LOCAL` and so cannot
 *         be received via `Context.registerReceiver` from a
 *         manifest declaration; we accept the
 *         `BECOMING_NOISY` semantic for "headphones
 *         connected" probe and let the Dart side cross-check
 *         with `AudioManager.getDevices(...)` on demand)
 *       - `ACTION_SCREEN_ON` / `ACTION_SCREEN_OFF`
 *     Battery level is read on every snapshot via
 *     `BatteryManager.BATTERY_PROPERTY_CAPACITY` (API 21+,
 *     zero-latency sticky read — does not require a battery
 *     broadcast subscription).
 *
 * The Dart side is the source of truth for "which state
 * changes are interesting" (the routine executor matches
 * trigger shapes against the stream in PR 2). The Kotlin
 * side is stateless w.r.t. the routines — it only knows
 * how to read the current state and push changes.
 *
 * The receivers are registered in `startStream` and
 * unregistered in `stopStream` (or `detach`). No foreground
 * service is required: these broadcasts fire even in Doze.
 * Per ADR-022 the poll cadence is 60 seconds for any
 * non-reactive state, but the broadcasts above are reactive
 * so we do not poll for them — `currentSnapshot()` is
 * on-demand only.
 */
object DeviceStateChannel {
    private const val CHANNEL = "doit/device_state"
    private const val SINK_METHOD = "onDeviceState"

    private var channel: MethodChannel? = null
    private var streamStarted: Boolean = false

    fun attach(engine: FlutterEngine) {
        val ch = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "currentSnapshot" -> {
                    val ctx = appContext
                    if (ctx == null) {
                        result.error(
                            "NO_CONTEXT",
                            "DeviceStateChannel has no app context",
                            null,
                        )
                    } else {
                        result.success(snapshotMap(ctx))
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
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_POWER_CONNECTED)
            addAction(Intent.ACTION_POWER_DISCONNECTED)
            addAction(AudioManager.ACTION_AUDIO_BECOMING_NOISY)
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ctx.registerReceiver(
                streamingReceiver,
                filter,
                Context.RECEIVER_NOT_EXPORTED,
            )
        } else {
            ctx.registerReceiver(streamingReceiver, filter)
        }
        streamStarted = true
        // Push the current state immediately so the Dart
        // side has a baseline snapshot on first subscribe.
        pushSnapshot(ctx)
    }

    private fun stopStream() {
        if (!streamStarted) return
        val ctx = appContext
        if (ctx != null) {
            try {
                ctx.unregisterReceiver(streamingReceiver)
            } catch (_: IllegalArgumentException) {
                // Already unregistered. Ignore.
            }
        }
        streamStarted = false
    }

    /**
     * The single receiver that handles every broadcast we
     * care about. Dispatches to `pushSnapshot` for any
     * matching action.
     */
    private val streamingReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            pushSnapshot(context)
        }
    }

    private fun pushSnapshot(context: Context) {
        val map = snapshotMap(context)
        channel?.invokeMethod(SINK_METHOD, map)
    }

    /**
     * Read the current device state into a stable map shape.
     * Keys:
     *   - `batteryPercent: Int` (0..100)
     *   - `isCharging: Boolean`
     *   - `headphonesConnected: Boolean`
     *   - `screenOn: Boolean`
     */
    private fun snapshotMap(context: Context): Map<String, Any> {
        val bm = context.getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
        val level = bm?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY) ?: 0
        val batteryPercent = if (level in 0..100) level else 0
        val isCharging = bm?.isCharging == true

        val am = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        val headphonesConnected = am?.let { isAnyHeadphonesOutput(it) } ?: false

        val pm = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
        val screenOn = pm?.isInteractive == true

        return mapOf(
            "batteryPercent" to batteryPercent,
            "isCharging" to isCharging,
            "headphonesConnected" to headphonesConnected,
            "screenOn" to screenOn,
        )
    }

    /**
     * Returns true if any connected audio output device is a
     * wired or wireless headset. We avoid the deprecated
     * `isWiredHeadsetOn()` / `isBluetoothA2dpOn()` and walk
     * `AudioManager.getDevices(GET_DEVICES_OUTPUTS)` instead.
     */
    private fun isAnyHeadphonesOutput(am: AudioManager): Boolean {
        val outputs = runCatching { am.getDevices(AudioManager.GET_DEVICES_OUTPUTS) }
            .getOrNull() ?: return false
        return outputs.any { device ->
            device.type == AudioDeviceInfo.TYPE_WIRED_HEADSET ||
                device.type == AudioDeviceInfo.TYPE_WIRED_HEADPHONES ||
                device.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP ||
                device.type == AudioDeviceInfo.TYPE_BLE_HEADSET ||
                device.type == AudioDeviceInfo.TYPE_USB_HEADSET
        }
    }

    @Volatile
    private var appContext: Context? = null

    fun setAppContext(ctx: Context) {
        appContext = ctx.applicationContext
    }
}

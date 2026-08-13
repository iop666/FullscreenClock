package com.fullscreenclock.fullscreen_clock

import android.content.pm.ActivityInfo
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val refreshChannel = "fullscreenclock/refresh_rate"
    private val orientationChannel = "fullscreenclock/orientation"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 感知陀螺仪:默认跟随传感器方向自动旋转(横竖屏)
        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, refreshChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setRefreshRate" -> {
                        val rate = (call.arguments as? Number)?.toFloat() ?: -1f
                        setPreferredRefreshRate(rate)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, orientationChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setLandscapeLock" -> {
                        val locked = (call.arguments as? Boolean) ?: false
                        requestedOrientation = if (locked) {
                            ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
                        } else {
                            ActivityInfo.SCREEN_ORIENTATION_SENSOR
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * 设置窗口首选刷新率:
     * - rate <= 0:恢复到屏幕支持的最高刷新率(如 120Hz)
     * - rate > 0:请求该刷新率(如 1Hz 用于省电)
     */
    private fun setPreferredRefreshRate(rate: Float) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return
        val lp = window.attributes
        if (rate <= 0f) {
            val display = window.windowManager.defaultDisplay
            val maxRefresh = display.supportedModes.maxOfOrNull { it.refreshRate }
            lp.preferredRefreshRate = if (maxRefresh != null && maxRefresh > 0f) maxRefresh else -1f
        } else {
            lp.preferredRefreshRate = rate
        }
        window.attributes = lp
    }
}

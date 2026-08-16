package com.fullscreenclock.fullscreen_clock

import android.app.Activity
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.PowerManager
import android.provider.MediaStore
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * 计划功能的原生通道(fullscreenclock/plan):
 * 前台服务 / AlarmManager 调度 / 电池优化与精确闹钟引导 / 小米灵动岛探测 / SAF 保存导出。
 */
object PlanChannels {
    const val CHANNEL = "fullscreenclock/plan"
    const val REQ_SAVE = 4001

    private var planContext: Context? = null
    private var pendingResult: MethodChannel.Result? = null
    private var pendingContent: String? = null

    fun register(engine: FlutterEngine, context: Context) {
        planContext = context
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickSaveLocation" -> {
                        // SAF 保存对话框:先生成 JSON 内容,用户选择保存位置后写入
                        val args = call.arguments as? Map<*, *>
                        val fileName = args?.get("fileName") as? String ?: "export.json"
                        val content = args?.get("content") as? String ?: ""
                        val activity = planContext as? Activity
                        if (activity == null) {
                            result.success(null)
                        } else {
                            pendingContent = content
                            pendingResult = result
                            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "application/json"
                                putExtra(Intent.EXTRA_TITLE, fileName)
                            }
                            activity.startActivityForResult(intent, REQ_SAVE)
                        }
                    }
                    "startPlanService" -> {
                        val text = call.arguments as? String ?: "常驻提醒已开启"
                        PlanForegroundService.start(planContext!!, text)
                        result.success(true)
                    }
                    "stopPlanService" -> {
                        PlanForegroundService.stop(planContext!!)
                        result.success(true)
                    }
                    "scheduleAlarms" -> {
                        val events = call.arguments as? String ?: "[]"
                        AlarmScheduler.schedule(planContext!!, events)
                        result.success(true)
                    }
                    "cancelAlarms" -> {
                        AlarmScheduler.cancelAll(planContext!!)
                        result.success(true)
                    }
                    "canScheduleExactAlarms" -> {
                        result.success(AlarmScheduler.canScheduleExact(planContext!!))
                    }
                    "openExactAlarmSettings" -> {
                        AlarmScheduler.openExactAlarmSettings(planContext!!)
                        result.success(true)
                    }
                    "openBatteryOptimizationSettings" -> {
                        try {
                            val intent = Intent(
                                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                Uri.parse("package:" + planContext!!.packageName)
                            )
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            planContext!!.startActivity(intent)
                        } catch (e: Exception) {
                            // 忽略
                        }
                        result.success(true)
                    }
                    "isIgnoringBatteryOptimizations" -> {
                        val ctx = planContext!!
                        val pm = ctx.getSystemService(Context.POWER_SERVICE) as PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(ctx.packageName))
                    }
                    "isMiuiIslandSupported" -> {
                        result.success(MiuiIslandHelper.isIslandSupported())
                    }
                    "detectBrand" -> {
                        result.success(android.os.Build.MANUFACTURER)
                    }
                    "writeContentFile" -> {
                        val args = call.arguments as? Map<*, *>
                        val uri = args?.get("uri") as? String ?: ""
                        val content = args?.get("content") as? String ?: ""
                        result.success(
                            try {
                                val parsed = Uri.parse(uri)
                                planContext!!.contentResolver.openOutputStream(parsed)?.use { os ->
                                    os.write(content.toByteArray(Charsets.UTF_8))
                                }
                                true
                            } catch (e: Exception) {
                                false
                            }
                        )
                    }
                    "saveToDownloads" -> {
                        val args = call.arguments as? Map<*, *>
                        val fileName = args?.get("fileName") as? String ?: "export.json"
                        val content = args?.get("content") as? String ?: ""
                        val ctx = planContext!!
                        result.success(
                            try {
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                                    val values = ContentValues().apply {
                                        put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                                        put(MediaStore.MediaColumns.MIME_TYPE, "application/json")
                                        put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                                    }
                                    val uri = ctx.contentResolver.insert(
                                        MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                                    if (uri != null) {
                                        ctx.contentResolver.openOutputStream(uri)?.use { os ->
                                            os.write(content.toByteArray(Charsets.UTF_8))
                                        }
                                        uri.toString()
                                    } else {
                                        null
                                    }
                                } else {
                                    val dir = ctx.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
                                    val f = File(dir, fileName)
                                    f.writeText(content)
                                    f.absolutePath
                                }
                            } catch (e: Exception) {
                                null
                            }
                        )
                    }
                    "detectFocusProtocol" -> {
                        result.success(MiuiIslandHelper.focusProtocolVersion(planContext!!))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /// 由 MainActivity.onActivityResult 调用:写入用户选择的 content URI 并回调 dart
    fun handleSaveResult(resultCode: Int, data: Intent?) {
        val res = pendingResult
        pendingResult = null
        val content = pendingContent
        pendingContent = null
        if (resultCode == Activity.RESULT_OK && data?.data != null && content != null) {
            try {
                val uri = data.data!!
                planContext?.contentResolver?.openOutputStream(uri)?.use { os ->
                    os.write(content.toByteArray(Charsets.UTF_8))
                }
                res?.success(uri.toString())
            } catch (e: Exception) {
                res?.success(null)
            }
        } else {
            res?.success(null) // 用户取消
        }
    }
}

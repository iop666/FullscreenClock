package com.fullscreenclock.fullscreen_clock

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import org.json.JSONArray

/**
 * AlarmManager 调度:每次由 Dart 全量下发未来 N 个事件,先取消旧的再全量设置。
 * 事件 JSON 存于本地 prefs,供 BootReceiver 开机重排。
 */
object AlarmScheduler {
    private const val PREFS = "plan_alarm_schedule"
    private const val KEY_EVENTS = "events"

    fun schedule(context: Context, eventsJson: String) {
        cancelAll(context)
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val array = try {
            JSONArray(eventsJson)
        } catch (e: Exception) {
            JSONArray()
        }
        for (i in 0 until array.length()) {
            val e = array.optJSONObject(i) ?: continue
            val at = e.optLong("atEpochMs")
            val type = e.optString("type", "start")
            val planId = e.optString("planId", "plan")
            val title = e.optString("title", "计划提醒")
            val channel = e.optString("channel", "plan_start")
            val visibility = e.optInt("visibility", 1)
            val minBefore = e.optInt("minBefore", 0)
            if (at <= 0) continue

            val requestCode = (planId + "|" + type).hashCode() and 0x7FFFFFFF
            val intent = Intent(context, AlarmReceiver::class.java)
                .putExtra("type", type)
                .putExtra("planId", planId)
                .putExtra("title", title)
                .putExtra("channel", channel)
                .putExtra("visibility", visibility)
                .putExtra("minBefore", minBefore)
            val pi = PendingIntent.getBroadcast(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            if (canScheduleExact(context)) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
            } else {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
            }
            // 记录 requestCode 用于取消与重排
            e.put("requestCode", requestCode)
        }
        prefs.edit().putString(KEY_EVENTS, array.toString()).apply()
    }

    fun cancelAll(context: Context) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val old = prefs.getString(KEY_EVENTS, null)
        if (old != null) {
            try {
                val arr = JSONArray(old)
                for (i in 0 until arr.length()) {
                    val e = arr.optJSONObject(i) ?: continue
                    val rc = e.optInt("requestCode", -1)
                    if (rc < 0) continue
                    val pi = PendingIntent.getBroadcast(
                        context, rc,
                        Intent(context, AlarmReceiver::class.java),
                        PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
                    )
                    if (pi != null) am.cancel(pi)
                }
            } catch (e: Exception) {
                // 忽略解析错误
            }
        }
        prefs.edit().remove(KEY_EVENTS).apply()
    }

    fun canScheduleExact(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        return am.canScheduleExactAlarms()
    }

    fun openExactAlarmSettings(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try {
                val intent = Intent(
                    Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                    Uri.parse("package:" + context.packageName)
                )
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
            } catch (e: Exception) {
                // 忽略
            }
        }
    }

    fun rescheduleOnBoot(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val json = prefs.getString(KEY_EVENTS, null) ?: return
        schedule(context, json)
    }
}

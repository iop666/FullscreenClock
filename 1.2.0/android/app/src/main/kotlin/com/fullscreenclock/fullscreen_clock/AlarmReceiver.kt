package com.fullscreenclock.fullscreen_clock

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * 闹钟到点广播:直接发通知(进程被杀时仍生效)。
 * 状态对账由 Dart 侧在下次启动时 reconcile 完成。
 */
class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val type = intent.getStringExtra("type") ?: "start"
        val planId = intent.getStringExtra("planId") ?: "plan"
        val title = intent.getStringExtra("title") ?: "计划提醒"
        val channel = intent.getStringExtra("channel") ?: "plan_start"
        val visibility = intent.getIntExtra("visibility", android.app.Notification.VISIBILITY_PUBLIC)
        val minBefore = intent.getIntExtra("minBefore", 0)

        val body = when (type) {
            "reminder" -> if (minBefore > 0) "「$title」将在 $minBefore 分钟后开始" else "「$title」马上开始"
            "start" -> "计划「$title」开始,专注起来"
            "overdue" -> "计划「$title」超时,请处理(放弃 / 完成 / 继续并加时)"
            else -> title
        }
        PlanNotifier.show(context, type, planId, title, channel, visibility, body)
    }
}

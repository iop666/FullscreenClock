package com.fullscreenclock.fullscreen_clock

import android.Manifest
import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build

/**
 * 原生侧直接发通知(用于 AlarmReceiver 到点提醒,不依赖 Flutter 引擎)。
 * 渠道已在 Dart 侧(flutter_local_notifications)创建,这里复用同一渠道。
 */
object PlanNotifier {
    private const val CHANNEL_PERSISTENT = "plan_persistent"
    private const val CHANNEL_START = "plan_start"
    private const val CHANNEL_OVERDUE = "plan_overdue"
    private const val CHANNEL_REMINDER = "plan_reminder"

    /// 常驻通知/前台服务通知 id(与 Dart 侧 PlanNotificationService 一致)
    const val NOTIF_ID = 1001

    fun show(
        context: Context,
        type: String,
        planId: String,
        title: String,
        channel: String,
        visibility: Int,
        extraBody: String? = null,
    ) {
        if (Build.VERSION.SDK_INT >= 33 &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)
            != PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val builder = if (Build.VERSION.SDK_INT >= 26) {
            Notification.Builder(context, channel)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        val body = when (type) {
            "reminder" -> extraBody ?: "计划即将开始"
            "start" -> "计划开始了,开始专注吧"
            "overdue" -> "计划超时,请处理(放弃 / 完成 / 继续并加时)"
            else -> title
        }
        builder
            .setSmallIcon(R.drawable.ic_stat_plan)
            .setContentTitle(title)
            .setContentText(body)
            .setVisibility(visibility)
            .setAutoCancel(true)
            .setPriority(Notification.PRIORITY_HIGH)
        val id = (planId + "|" + type).hashCode() and 0x3FFFFFFF
        nm.notify(id, builder.build())
    }

    fun buildPersistent(context: Context, text: String): Notification {
        if (Build.VERSION.SDK_INT >= 26) {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = android.app.NotificationChannel(
                CHANNEL_PERSISTENT, "计划常驻进度", NotificationManager.IMPORTANCE_LOW
            )
            channel.setShowBadge(false)
            nm.createNotificationChannel(channel)
        }
        return if (Build.VERSION.SDK_INT >= 26) {
            Notification.Builder(context, CHANNEL_PERSISTENT)
                .setSmallIcon(R.drawable.ic_stat_plan)
                .setContentTitle("全屏时钟计划")
                .setContentText(text)
                .setOngoing(true)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
                .setSmallIcon(R.drawable.ic_stat_plan)
                .setContentTitle("全屏时钟计划")
                .setContentText(text)
                .setOngoing(true)
                .build()
        }
    }
}

package com.fullscreenclock.fullscreen_clock

import android.app.Notification
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder

/**
 * 计划前台服务(specialUse):保证常驻通知与准点提醒的进程存活。
 * 常驻通知内容由 Dart 侧通过同 id 更新;服务本身只负责保活。
 */
class PlanForegroundService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val text = intent?.getStringExtra(EXTRA_TEXT) ?: "常驻提醒已开启"
        startForeground(PlanNotifier.NOTIF_ID, PlanNotifier.buildPersistent(this, text))
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        val nm = getSystemService(Context.NOTIFICATION_SERVICE)
            as android.app.NotificationManager
        nm.cancel(PlanNotifier.NOTIF_ID)
    }

    companion object {
        private const val EXTRA_TEXT = "text"

        fun start(context: Context, text: String) {
            val intent = Intent(context, PlanForegroundService::class.java)
                .putExtra(EXTRA_TEXT, text)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, PlanForegroundService::class.java))
        }
    }
}

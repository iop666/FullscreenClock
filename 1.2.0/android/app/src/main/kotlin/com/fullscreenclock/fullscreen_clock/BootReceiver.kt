package com.fullscreenclock.fullscreen_clock

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * 开机自启:重排已调度的闹钟(进程被杀后开机仍可准点提醒)。
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            AlarmScheduler.rescheduleOnBoot(context)
        }
    }
}

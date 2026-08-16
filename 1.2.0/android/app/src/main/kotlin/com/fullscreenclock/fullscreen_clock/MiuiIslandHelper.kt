package com.fullscreenclock.fullscreen_clock

import android.content.Context
import android.provider.Settings

/**
 * 小米 HyperOS 超级岛/焦点通知能力探测与参数封装(预留)。
 * 准入需平台侧审核(开发者认证+场景预审+方案审核+白名单),本类默认只做探测,
 * 参数构建由 Dart 侧 MiuiIslandService 在获得准入后启用。
 */
object MiuiIslandHelper {

    /** 是否支持岛(反射 SystemProperties) */
    fun isIslandSupported(): Boolean {
        return try {
            val clazz = Class.forName("android.os.SystemProperties")
            val get = clazz.getMethod("get", String::class.java)
            val v = get.invoke(null, "persist.sys.feature.island") as String
            v == "true" || v == "1"
        } catch (e: Throwable) {
            false
        }
    }

    /** 焦点通知/岛协议版本:1=OS1, 2=OS2, 3=OS3 */
    fun focusProtocolVersion(context: Context): Int {
        return try {
            Settings.System.getInt(
                context.contentResolver,
                "notification_focus_protocol",
                0
            )
        } catch (e: Throwable) {
            0
        }
    }
}

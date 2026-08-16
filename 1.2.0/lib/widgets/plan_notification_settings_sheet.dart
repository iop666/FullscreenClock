import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../providers/plan_provider.dart';
import '../services/plan_alarm_service.dart';
import '../services/miui_island_service.dart';
import '../theme/app_theme.dart';

/// 计划通知设置面板(底部弹层):渠道开关、锁屏可见性、后台权限引导。
class PlanNotificationSettingsSheet extends StatelessWidget {
  const PlanNotificationSettingsSheet({
    super.key,
    required this.planProvider,
    required this.palette,
  });

  final PlanProvider planProvider;
  final Palette palette;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: planProvider,
      builder: (context, _) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '计划通知设置',
                  style: TextStyle(
                    color: palette.foreground,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '各渠道可独立开关,系统设置中也可分别关闭',
                  style: TextStyle(color: palette.secondary, fontSize: 12),
                ),
                const SizedBox(height: 12),
                _switch(
                  title: '常驻进度通知',
                  subtitle: '显示当前计划、剩余时间与下一计划',
                  value: planProvider.persistentNotif,
                  onChanged: planProvider.setPersistentNotif,
                ),
                _switch(
                  title: '开始提醒',
                  subtitle: '计划开始时通知',
                  value: planProvider.startNotif,
                  onChanged: planProvider.setStartNotif,
                ),
                _switch(
                  title: '超时提醒',
                  subtitle: '计划超时后提醒处理',
                  value: planProvider.overdueNotif,
                  onChanged: planProvider.setOverdueNotif,
                ),
                _switch(
                  title: '提前提醒',
                  subtitle: '开始前 10 分钟提醒',
                  value: planProvider.reminderNotif,
                  onChanged: planProvider.setReminderNotif,
                ),
                if (!Platform.isWindows) ...[
                  _divider(),
                  _label('后台稳定性'),
                  const SizedBox(height: 8),
                  FutureBuilder<bool>(
                    future: PlanAlarmService.canScheduleExactAlarms(),
                    builder: (context, snap) {
                      final ok = snap.data ?? true;
                      return _permissionRow(
                        title: '精确闹钟',
                        ok: ok,
                        okText: '已授权,计划到点可准时提醒',
                        badText: '未授权,到点提醒可能不准确',
                        onTap: ok
                            ? null
                            : () => PlanAlarmService.openExactAlarmSettings(),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  FutureBuilder<bool>(
                    future: PlanAlarmService.isIgnoringBatteryOptimizations(),
                    builder: (context, snap) {
                      final ok = snap.data ?? true;
                      return _permissionRow(
                        title: '电池优化',
                        ok: ok,
                        okText: '未限制,后台提醒正常',
                        badText: '已限制,后台提醒可能被系统拦截',
                        onTap: ok
                            ? null
                            : () => PlanAlarmService
                                .openBatteryOptimizationSettings(),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  FutureBuilder<String?>(
                    future: PlanAlarmService.detectBrand(),
                    builder: (context, snap) {
                      final brand = snap.data;
                      final name = MiuiIslandService.islandNameForBrand(brand);
                      final supported = name != null;
                      return _permissionRow(
                        title: '灵动岛兼容',
                        ok: supported,
                        okText: supported
                            ? '当前设备支持 ${brand ?? ''} 的 $name,将在后续更新中适配'
                            : '当前设备不支持${brand == null || brand.isEmpty ? '' : '($brand)'}的灵动岛',
                        badText: '当前设备不支持灵动岛',
                        onTap: null,
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '国内 ROM 建议:系统设置 → 应用自启动、后台弹窗权限中允许本应用,并关闭电池优化,以保证后台提醒。',
                    style: TextStyle(color: palette.secondary, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _label(String text) => Text(
        text,
        style: TextStyle(color: palette.secondary, fontSize: 13, letterSpacing: 1),
      );

  Widget _divider() => Divider(height: 20, thickness: 1, color: palette.cardBorder);

  Widget _switch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: TextStyle(color: palette.foreground, fontSize: 15)),
      subtitle:
          Text(subtitle, style: TextStyle(color: palette.secondary, fontSize: 12)),
      value: value,
      activeThumbColor: palette.accent,
      activeTrackColor: palette.accent.withValues(alpha: 0.35),
      onChanged: onChanged,
    );
  }

  Widget _permissionRow({
    required String title,
    required bool ok,
    required String okText,
    required String badText,
    required VoidCallback? onTap,
  }) {
    final color = ok ? const Color(0xFF1FAF58) : const Color(0xFFE53935);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(ok ? Icons.check_circle : Icons.error_outline, color: color),
      title: Text(title, style: TextStyle(color: palette.foreground, fontSize: 15)),
      subtitle: Text(
        ok ? okText : badText,
        style: TextStyle(color: palette.secondary, fontSize: 12),
      ),
      trailing: onTap == null
          ? null
          : TextButton(
              onPressed: onTap,
              child: Text('去设置', style: TextStyle(color: palette.accent)),
            ),
    );
  }
}

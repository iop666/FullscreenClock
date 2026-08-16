import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'providers/plan_provider.dart';
import 'providers/settings_provider.dart';
import 'services/font_service.dart';
import 'services/plan_alarm_service.dart';
import 'services/plan_backup_service.dart';
import 'services/plan_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Windows 桌面端需要初始化窗口管理器(用于全屏/退出全屏)
  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
  }
  // 启动前从本地加载持久化设置
  final provider = await SettingsProvider.load();
  final planProvider = await PlanProvider.load();
  // 若存在已导入的自定义字体,注册到引擎
  if (provider.settings.customFontFamily != null) {
    await FontService.loadInstalledFont();
  }
  // 初始化计划通知(Android:创建渠道 + 请求权限;Windows:空操作)
  await PlanNotificationService.init();
  // 注入通知/闹钟回调(provider 保持可单测)
  planProvider.reminderCallback = (occ, min) =>
      PlanNotificationService.onReminder(planProvider, occ, min);
  planProvider.onStatusChanged = (occ, old, nw) =>
      PlanNotificationService.onStatusChanged(planProvider, occ, old, nw);
  planProvider.persistentTickCallback = (now) =>
      PlanNotificationService.updatePersistent(planProvider, now);
  planProvider.schedulingCallback = () =>
      PlanAlarmService.refresh(planProvider);
  // 启动时自动备份(后台,不阻塞启动)
  unawaited(PlanBackupService.maybeBackup(planProvider));
  runApp(FullscreenClockApp(provider: provider, planProvider: planProvider));
}

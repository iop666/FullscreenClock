import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'providers/settings_provider.dart';
import 'services/font_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Windows 桌面端需要初始化窗口管理器(用于全屏/退出全屏)
  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
  }
  // 启动前从本地加载持久化设置
  final provider = await SettingsProvider.load();
  // 若存在已导入的自定义字体,注册到引擎
  if (provider.settings.customFontFamily != null) {
    await FontService.loadInstalledFont();
  }
  runApp(FullscreenClockApp(provider: provider));
}

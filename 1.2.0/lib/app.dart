import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'providers/plan_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/clock_screen.dart';

/// 应用根组件
class FullscreenClockApp extends StatelessWidget {
  const FullscreenClockApp({
    super.key,
    required this.provider,
    required this.planProvider,
  });

  final SettingsProvider provider;
  final PlanProvider planProvider;

  /// Windows 上默认 fallback 会让个别汉字(如 关/类)渲染异常;
  /// 打包的 HarmonyOS Sans 实为拉丁精简版(不含中文),故直接用系统
  /// 自带、含完整中文的 Microsoft YaHei 作为 UI 字体;
  /// Android 保持系统字体(小米设备为 MiSans)。
  static String? get _uiFontFamily =>
      Platform.isWindows ? 'Microsoft YaHei' : null;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fullscreen Clock',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: _uiFontFamily,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
        scaffoldBackgroundColor: Colors.black,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        fontFamily: _uiFontFamily,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.black,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: Colors.black,
      ),
      // 中文日期/时间选择器等系统组件本地化
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh'), Locale('en')],
      home: ClockScreen(provider: provider, planProvider: planProvider),
    );
  }
}

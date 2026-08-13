import 'package:flutter/material.dart';

import 'providers/settings_provider.dart';
import 'screens/clock_screen.dart';

/// 应用根组件
class FullscreenClockApp extends StatelessWidget {
  const FullscreenClockApp({super.key, required this.provider});

  final SettingsProvider provider;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fullscreen Clock',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
        scaffoldBackgroundColor: Colors.black,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.black,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: Colors.black,
      ),
      home: ClockScreen(provider: provider),
    );
  }
}

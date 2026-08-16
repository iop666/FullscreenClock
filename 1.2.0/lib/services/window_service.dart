import 'dart:io' show Platform;

import 'package:window_manager/window_manager.dart';

/// Windows 窗口全屏控制
///
/// 默认以窗口模式启动;用户按 F11 / ESC 切换全屏,setFullScreen 会隐藏
/// 标题栏与任务栏,真正覆盖整个屏幕。
class WindowService {
  WindowService._();

  static final WindowService instance = WindowService._();

  bool _isFull = false;

  bool get isWindows => Platform.isWindows;
  bool get isFull => _isFull;

  Future<void> toggle() async {
    if (isWindows) await setFullscreen(!_isFull);
  }

  Future<void> exit() async {
    if (isWindows && _isFull) await setFullscreen(false);
  }

  Future<void> setFullscreen(bool full) async {
    if (!isWindows) return;
    try {
      await windowManager.setFullScreen(full);
      _isFull = full;
    } catch (_) {}
  }
}

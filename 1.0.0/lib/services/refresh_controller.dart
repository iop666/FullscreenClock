import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Android 屏幕刷新率控制(用于省电)
///
/// 标准时钟无操作时把屏幕降到 1Hz 省电,有操作恢复高刷新率。
class RefreshController {
  RefreshController._();

  static const _channel = MethodChannel('fullscreenclock/refresh_rate');

  /// 进入省电:降到 1Hz
  static void enterPowerSave() {
    if (Platform.isAndroid) {
      _channel.invokeMethod('setRefreshRate', 1.0).catchError((Object _) {});
    }
  }

  /// 退出省电:恢复系统自动刷新率(高刷)
  static void exitPowerSave() {
    if (Platform.isAndroid) {
      _channel.invokeMethod('setRefreshRate', -1.0).catchError((Object _) {});
    }
  }
}

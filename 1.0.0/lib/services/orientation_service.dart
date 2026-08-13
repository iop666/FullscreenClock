import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Android 屏幕方向控制:锁定/解锁横屏
class OrientationService {
  OrientationService._();

  static const _channel = MethodChannel('fullscreenclock/orientation');

  /// 锁定横屏(保持当前横屏方向)或解锁(恢复跟随陀螺仪)
  static Future<void> setLandscapeLock(bool locked) async {
    if (Platform.isAndroid) {
      _channel.invokeMethod('setLandscapeLock', locked).catchError((Object _) {});
    }
  }
}

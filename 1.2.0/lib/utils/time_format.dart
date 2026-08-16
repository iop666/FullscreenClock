import 'package:flutter/foundation.dart';

import '../models/clock_settings.dart';

/// 解析后的时间各组成部分
@immutable
class TimeParts {
  const TimeParts({
    required this.hours,
    required this.minutes,
    required this.seconds,
    this.ampm = '',
  });

  final String hours;
  final String minutes;
  final String seconds;

  /// 12 小时制下为 'AM' / 'PM',24 小时制为空字符串
  final String ampm;
}

/// 根据设置解析时间(统一 12/24 小时制与补零逻辑)
TimeParts buildTimeParts(DateTime time, ClockSettings settings) {
  String ampm = '';
  int h;
  if (settings.use24Hour) {
    h = time.hour;
  } else {
    final h12 = time.hour % 12;
    h = h12 == 0 ? 12 : h12;
    ampm = time.hour >= 12 ? 'PM' : 'AM';
  }
  return TimeParts(
    hours: h.toString().padLeft(2, '0'),
    minutes: time.minute.toString().padLeft(2, '0'),
    seconds: time.second.toString().padLeft(2, '0'),
    ampm: ampm,
  );
}

/// 标准时钟显示文本,如 "12:34" 或 "12:34:56"
String formatClockText(DateTime time, ClockSettings settings) {
  final parts = buildTimeParts(time, settings);
  final buf = StringBuffer()
    ..write(parts.hours)
    ..write(':')
    ..write(parts.minutes);
  if (settings.showSeconds) {
    buf.write(':');
    buf.write(parts.seconds);
  }
  return buf.toString();
}

import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../models/plan.dart';
import '../providers/plan_provider.dart';
import '../utils/plan_time.dart';
import 'plan_notification_service.dart';

/// 原生 AlarmManager 调度封装(进程被杀后仍能准点提醒)。
class PlanAlarmService {
  PlanAlarmService._();

  static const MethodChannel _channel = MethodChannel('fullscreenclock/plan');

  /// 原生通道不可用时静默降级(false 后不再尝试)
  static bool _available = true;

  static Future<void> refresh(PlanProvider p) async {
    if (Platform.isWindows || !_available) return;
    try {
      await _syncForegroundService(p);
      if (!p.enabled || p.plans.isEmpty) {
        await _channel.invokeMethod('cancelAlarms');
        return;
      }
      final now = DateTime.now();
      final events = <Map<String, dynamic>>[];
      final seen = <String>{};

      for (final plan in p.plans) {
        // 找到该计划下一次未来实例
        final occ = _nextFutureOccurrence(plan, now);
        if (occ == null) continue;

        // 提前提醒事件
        for (final min in plan.remindersMinBefore) {
          // v1.1 提前提醒固定为开始前 10 分钟
          if (min != 10) continue;
          final at = occ.scheduledStart.subtract(const Duration(minutes: 10));
          if (at.isAfter(now)) {
            final key = '${plan.id}|reminder|10';
            if (seen.add(key)) {
              events.add(_event(
                at: at,
                type: 'reminder',
                plan: plan,
                channel: 'plan_reminder',
                extra: {'minBefore': 10},
              ));
            }
          }
        }

        // 开始事件
        if (occ.scheduledStart.isAfter(now)) {
          final key = '${plan.id}|start';
          if (seen.add(key)) {
            events.add(_event(
              at: occ.scheduledStart,
              type: 'start',
              plan: plan,
              channel: 'plan_start',
            ));
          }
        }

        // 超时事件(原定结束时间)
        if (occ.scheduledEnd.isAfter(now)) {
          final key = '${plan.id}|overdue';
          if (seen.add(key)) {
            events.add(_event(
              at: occ.scheduledEnd,
              type: 'overdue',
              plan: plan,
              channel: 'plan_overdue',
            ));
          }
        }
      }

      events.sort(
          (a, b) => (a['atEpochMs'] as int).compareTo(b['atEpochMs'] as int));
      final limited = events.take(20).toList();
      await _channel.invokeMethod('scheduleAlarms', jsonEncode(limited));
    } catch (_) {
      _available = false;
    }
  }

  /// 根据启用/常驻通知开关同步前台服务的启动与停止
  static Future<void> _syncForegroundService(PlanProvider p) async {
    try {
      if (p.enabled && p.persistentNotif) {
        await _channel.invokeMethod('startPlanService', '常驻提醒已开启');
      } else {
        await _channel.invokeMethod('stopPlanService');
      }
    } catch (_) {
      // 忽略
    }
  }

  static Future<bool> canScheduleExactAlarms() async {
    if (Platform.isWindows) return true;
    try {
      final v = await _channel.invokeMethod<bool>('canScheduleExactAlarms');
      return v ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> openExactAlarmSettings() async {
    if (Platform.isWindows) return;
    try {
      await _channel.invokeMethod('openExactAlarmSettings');
    } catch (_) {}
  }

  static Future<void> openBatteryOptimizationSettings() async {
    if (Platform.isWindows) return;
    try {
      await _channel.invokeMethod('openBatteryOptimizationSettings');
    } catch (_) {}
  }

  static Future<bool> isIgnoringBatteryOptimizations() async {
    if (Platform.isWindows) return true;
    try {
      final v =
          await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
      return v ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<bool> isMiuiIslandSupported() async {
    if (Platform.isWindows) return false;
    try {
      final v = await _channel.invokeMethod<bool>('isMiuiIslandSupported');
      return v ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 读取设备品牌(如 Xiaomi / HUAWEI 等),供灵动岛兼容识别
  static Future<String?> detectBrand() async {
    if (Platform.isWindows) return null;
    try {
      return await _channel.invokeMethod<String>('detectBrand');
    } catch (_) {
      return null;
    }
  }

  static PlanOccurrence? _nextFutureOccurrence(Plan plan, DateTime now) {
    final start = startOfDay(now);
    for (var d = start;
        d.isBefore(start.add(const Duration(days: 366)));
        d = d.add(const Duration(days: 1))) {
      final o = occurrenceOn(plan, d);
      if (o == null) continue;
      if (o.scheduledEnd.isAfter(now)) return o;
      if (sameDay(d, now)) return null; // 今天该计划已结束,跳过
    }
    return null;
  }

  static Map<String, dynamic> _event({
    required DateTime at,
    required String type,
    required Plan plan,
    required String channel,
    Map<String, dynamic>? extra,
  }) {
    return {
      'atEpochMs': at.millisecondsSinceEpoch,
      'type': type,
      'planId': plan.id,
      'title': plan.title,
      'channel': channel,
      'visibility': PlanNotificationService.visibilityInt(plan.lockVisibility),
      ...?extra,
    };
  }
}

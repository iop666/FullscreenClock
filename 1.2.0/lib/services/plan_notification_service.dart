import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/plan.dart';
import '../providers/plan_provider.dart';
import '../utils/plan_time.dart';

/// 计划通知服务:4 个渠道 + 常驻进度通知 + 状态事件提醒。
/// Android 走 flutter_local_notifications;Windows 端提醒由 ClockScreen 的
/// SnackBar 呈现(本服务在 Windows 上为空操作,见 provider 的 windowsNoticeCallback)。
class PlanNotificationService {
  PlanNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// 常驻通知/前台服务通知 id(与原生 PlanForegroundService 保持一致)
  static const int persistentNotifId = 1001;

  static const Map<String, String> _channelNames = {
    'plan_persistent': '计划常驻进度',
    'plan_start': '计划开始提醒',
    'plan_overdue': '计划超时提醒',
    'plan_reminder': '计划提前提醒',
  };

  /// 初始化(创建渠道 + 请求通知权限)。Windows 跳过。
  static Future<void> init({bool requestPermission = true}) async {
    if (_initialized || Platform.isWindows) return;
    const android = AndroidInitializationSettings('ic_stat_plan');
    await _plugin.initialize(
        settings: const InitializationSettings(android: android));
    _initialized = true;
    await _createChannels();
    if (requestPermission) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  static Future<void> _createChannels() async {
    final impl = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (impl == null) return;
    await impl.createNotificationChannel(const AndroidNotificationChannel(
      'plan_persistent',
      '计划常驻进度',
      description: '显示当前计划、剩余时间与下一计划(可关闭)',
      importance: Importance.low,
      showBadge: false,
    ));
    await impl.createNotificationChannel(const AndroidNotificationChannel(
      'plan_start',
      '计划开始提醒',
      description: '计划开始时提醒',
      importance: Importance.high,
    ));
    await impl.createNotificationChannel(const AndroidNotificationChannel(
      'plan_overdue',
      '计划超时提醒',
      description: '计划超时提醒',
      importance: Importance.max,
    ));
    await impl.createNotificationChannel(const AndroidNotificationChannel(
      'plan_reminder',
      '计划提前提醒',
      description: '计划开始前的提前提醒',
      importance: Importance.defaultImportance,
    ));
  }

  static Importance _importanceFor(String channel) => switch (channel) {
        'plan_persistent' => Importance.low,
        'plan_start' => Importance.high,
        'plan_overdue' => Importance.max,
        _ => Importance.defaultImportance,
      };

  static Priority _priorityFor(String channel) => switch (channel) {
        'plan_persistent' => Priority.low,
        'plan_start' => Priority.high,
        'plan_overdue' => Priority.max,
        _ => Priority.high,
      };

  static NotificationVisibility _visibility(LockScreenVisibility v) =>
      switch (v) {
        LockScreenVisibility.public => NotificationVisibility.public,
        LockScreenVisibility.private => NotificationVisibility.private,
        LockScreenVisibility.secret => NotificationVisibility.secret,
      };

  static int _idFor(String channel, String planId) {
    if (channel == 'plan_persistent') return persistentNotifId;
    return ('$planId|$channel').hashCode & 0x3FFFFFFF;
  }

  /// 锁屏可见性对应的原生常量值(供 AlarmReceiver 使用)
  static int visibilityInt(LockScreenVisibility v) => switch (v) {
        LockScreenVisibility.public => 1,
        LockScreenVisibility.private => 0,
        LockScreenVisibility.secret => -1,
      };

  static Future<void> _show({
    required String channel,
    required String planId,
    required String title,
    required String body,
    required LockScreenVisibility visibility,
    bool ongoing = false,
  }) async {
    if (Platform.isWindows) return;
    if (!_initialized) return;
    final details = AndroidNotificationDetails(
      channel,
      _channelNames[channel] ?? channel,
      channelDescription: '计划提醒',
      importance: _importanceFor(channel),
      priority: _priorityFor(channel),
      visibility: _visibility(visibility),
      ongoing: ongoing,
    );
    await _plugin.show(
      id: _idFor(channel, planId),
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: details),
    );
  }

  // ---- 事件入口(由 PlanProvider 回调调用)----

  /// 状态迁移
  static Future<void> onStatusChanged(
    PlanProvider p,
    PlanOccurrence occ,
    PlanStatus oldStatus,
    PlanStatus newStatus,
  ) async {
    final plan = occ.plan;
    if (Platform.isWindows) {
      final msg = switch ((oldStatus, newStatus)) {
        (PlanStatus.unstarted, PlanStatus.active) => '计划开始: ${plan.title}',
        (_, PlanStatus.overdue) => '计划超时: ${plan.title}',
        _ => null,
      };
      if (msg != null) p.windowsNoticeCallback?.call(msg);
      return;
    }
    switch ((oldStatus, newStatus)) {
      case (PlanStatus.unstarted, PlanStatus.active):
        if (p.startNotif) {
          await _show(
            channel: 'plan_start',
            planId: plan.id,
            title: '计划开始: ${plan.title}',
            body: '${_hhmm(occ.scheduledStart)} 开始,预计 ${plan.duration.inMinutes} 分钟',
            visibility: plan.lockVisibility,
          );
        }
        break;
      case (_, PlanStatus.overdue):
        if (p.overdueNotif) {
          await _show(
            channel: 'plan_overdue',
            planId: plan.id,
            title: '计划超时: ${plan.title}',
            body: '点击时钟页面的操作按钮处理(放弃 / 完成 / 继续并加时)',
            visibility: plan.lockVisibility,
          );
        }
        break;
      default:
        break;
    }
    // 常驻通知跟随状态变化刷新
    if (p.persistentNotif) await updatePersistent(p, DateTime.now());
  }

  /// 提前提醒(v1.1 固定为开始前 10 分钟;reminderNotif 开关控制)
  static Future<void> onReminder(
    PlanProvider p,
    PlanOccurrence occ,
    int minBefore,
  ) async {
    if (minBefore != 10) return;
    if (Platform.isWindows) {
      p.windowsNoticeCallback?.call('「${occ.plan.title}」将在 10 分钟后开始');
      return;
    }
    if (!p.reminderNotif) return;
    await _show(
      channel: 'plan_reminder',
      planId: occ.plan.id,
      title: '计划即将开始',
      body: '「${occ.plan.title}」将在 10 分钟后开始',
      visibility: occ.plan.lockVisibility,
    );
  }

  /// 刷新常驻通知(v1.1 不显示倒计时;显示预计结束实际时间点 + 下一计划名称与开始时间点)
  static Future<void> updatePersistent(
    PlanProvider p,
    DateTime now,
  ) async {
    if (Platform.isWindows || !p.persistentNotif) return;
    if (!_initialized) return;
    final occ = p.currentOccurrence(now);
    final next = p.nextPlanInfo(now);
    final nextText = next == null
        ? ''
        : '\n下一计划: ${next.title} · 开始 ${_hhmm(next.start)}';
    if (occ != null) {
      final rt = p.runtimeFor(occ) ??
          PlanRuntime(planId: occ.plan.id, dateKey: occ.dateKey);
      final end = effectiveEnd(occ, rt, now);
      await _show(
        channel: 'plan_persistent',
        planId: 'persistent',
        title: '当前计划: ${occ.plan.title}',
        body: '预计结束 ${_hhmm(end)}$nextText',
        visibility: occ.plan.lockVisibility,
        ongoing: true,
      );
    } else if (next != null) {
      await _show(
        channel: 'plan_persistent',
        planId: 'persistent',
        title: '下一计划',
        body: '${next.title} · 开始 ${_hhmm(next.start)}',
        visibility: LockScreenVisibility.public,
        ongoing: true,
      );
    } else {
      await _plugin.cancel(id: persistentNotifId);
    }
  }

  static String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

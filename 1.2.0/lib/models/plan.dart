import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Icons, IconData;

import 'plan_repeat.dart';

/// 解析 ISO 时间:带时区(如 `...Z` 或 `+08:00`)时转本地时间,
/// 避免 AI 生成的 UTC 时间在导入后整体偏移 8 小时。
DateTime parseIsoToLocal(String s) {
  final d = DateTime.tryParse(s);
  if (d == null) return DateTime.parse(s); // 无效时保持原有抛错行为
  return d.toLocal();
}

/// 计划可选图标(全部 const,保证图标 tree-shaking 生效)
const Map<String, IconData> kPlanIcons = {
  'schedule': Icons.schedule,
  'book': Icons.auto_stories,
  'fitness': Icons.fitness_center,
  'sleep': Icons.bedtime,
  'work': Icons.work,
  'school': Icons.school,
  'coffee': Icons.local_cafe,
  'home': Icons.home,
  'music': Icons.music_note,
  'flag': Icons.flag,
  'star': Icons.star,
  'target': Icons.adjust,
  'restaurant': Icons.restaurant,
  'directions_run': Icons.directions_run,
};

/// 计划状态机状态
enum PlanStatus { unstarted, active, paused, completed, overdue, skipped }

/// 进度类型(automatic=按时间自动;manual=开始后可手动改;none=不设置进度)
enum ProgressType { automatic, manual, none }

/// 锁屏可见性(private/secret 时正文会隐藏备注)
enum LockScreenVisibility { public, private, secret }

/// 通知渠道(用户可分别开关)
enum PlanChannel { persistent, start, overdue, reminder }

/// 调整类型
enum AdjustmentType { extend, shorten, continueAndExtend }

/// 一次暂停段(endedAt 为空表示正在暂停中)
@immutable
class PauseSegment {
  const PauseSegment({required this.startedAt, this.endedAt, this.reason});

  final DateTime startedAt;
  final DateTime? endedAt;
  final String? reason;

  /// 已完结段的时长;正在暂停中的段返回 0(实时暂停时长由 effectiveEnd 计算)
  Duration get duration =>
      endedAt == null ? Duration.zero : endedAt!.difference(startedAt);

  Map<String, dynamic> toJson() => {
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
        'reason': reason,
      };

  factory PauseSegment.fromJson(Map<String, dynamic> json) => PauseSegment(
        startedAt: DateTime.parse(json['startedAt'] as String),
        endedAt: json['endedAt'] != null
            ? DateTime.parse(json['endedAt'] as String)
            : null,
        reason: json['reason'] as String?,
      );
}

/// 一次加时/减时调整记录
@immutable
class PlanAdjustment {
  const PlanAdjustment({
    required this.type,
    required this.deltaMinutes,
    required this.appliedAt,
    this.note,
  });

  final AdjustmentType type;

  /// 分钟数:extend 为正、shorten 为负
  final int deltaMinutes;
  final DateTime appliedAt;
  final String? note;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'deltaMinutes': deltaMinutes,
        'appliedAt': appliedAt.toIso8601String(),
        'note': note,
      };

  factory PlanAdjustment.fromJson(Map<String, dynamic> json) {
    AdjustmentType? t;
    for (final e in AdjustmentType.values) {
      if (e.name == json['type']) t = e;
    }
    return PlanAdjustment(
      type: t ?? AdjustmentType.extend,
      deltaMinutes: (json['deltaMinutes'] as num?)?.toInt() ?? 0,
      appliedAt: DateTime.parse(json['appliedAt'] as String),
      note: json['note'] as String?,
    );
  }
}

/// 计划定义(持久化、可重复)。实时状态存于 [PlanRuntime]。
@immutable
class Plan {
  const Plan({
    required this.id,
    required this.title,
    this.type = '',
    this.topic = '',
    this.unit = '',
    this.notes = '',
    this.color = 0xFF3B6EF6,
    this.iconName = 'schedule',
    this.tags = const [],
    required this.startDate,
    required this.duration,
    this.timezone = 'local',
    this.allDay = false,
    this.repeat = const RepeatRule(),
    this.progressType = ProgressType.automatic,
    this.remindersMinBefore = const [5, 10],
    this.notificationEnabled = true,
    this.channel = PlanChannel.start,
    this.lockVisibility = LockScreenVisibility.public,
    this.order = 0,
    this.parentId,
    this.dependencyIds = const [],
  });

  final String id;
  final String title;

  /// 三级标签:计划类型(一级)/主题(二级)/单元(三级)
  final String type;
  final String topic;
  final String unit;
  final String notes;
  final int color;
  final String iconName;
  final List<String> tags;

  /// 锚定日期与时刻(重复计划以此为起点展开,时分秒作为每天的时刻)
  final DateTime startDate;

  /// 有效执行时长(暂停顺延后仍以此为基准)
  final Duration duration;
  final String timezone;
  final bool allDay;

  final RepeatRule repeat;
  final ProgressType progressType;

  /// 开始前 N 分钟提醒(正数,如 [5,10])
  final List<int> remindersMinBefore;
  final bool notificationEnabled;
  final PlanChannel channel;
  final LockScreenVisibility lockVisibility;
  final int order;
  final String? parentId;
  final List<String> dependencyIds;

  /// 某天该计划的开始时刻(复用锚点日期/时间)
  DateTime occurrenceStart(DateTime day) => DateTime(
        day.year,
        day.month,
        day.day,
        startDate.hour,
        startDate.minute,
        startDate.second,
      );

  IconData get iconData => kPlanIcons[iconName] ?? Icons.schedule;

  Plan copyWith({
    String? title,
    String? type,
    String? topic,
    String? unit,
    String? notes,
    int? color,
    String? iconName,
    List<String>? tags,
    DateTime? startDate,
    Duration? duration,
    String? timezone,
    bool? allDay,
    RepeatRule? repeat,
    ProgressType? progressType,
    List<int>? remindersMinBefore,
    bool? notificationEnabled,
    PlanChannel? channel,
    LockScreenVisibility? lockVisibility,
    int? order,
    String? parentId,
    List<String>? dependencyIds,
  }) {
    return Plan(
      id: id,
      title: title ?? this.title,
      type: type ?? this.type,
      topic: topic ?? this.topic,
      unit: unit ?? this.unit,
      notes: notes ?? this.notes,
      color: color ?? this.color,
      iconName: iconName ?? this.iconName,
      tags: tags ?? this.tags,
      startDate: startDate ?? this.startDate,
      duration: duration ?? this.duration,
      timezone: timezone ?? this.timezone,
      allDay: allDay ?? this.allDay,
      repeat: repeat ?? this.repeat,
      progressType: progressType ?? this.progressType,
      remindersMinBefore: remindersMinBefore ?? this.remindersMinBefore,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      channel: channel ?? this.channel,
      lockVisibility: lockVisibility ?? this.lockVisibility,
      order: order ?? this.order,
      parentId: parentId ?? this.parentId,
      dependencyIds: dependencyIds ?? this.dependencyIds,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type,
        'topic': topic,
        'unit': unit,
        'notes': notes,
        'color': color,
        'iconName': iconName,
        'tags': tags,
        'startDate': startDate.toIso8601String(),
        'durationMinutes': duration.inMinutes,
        'timezone': timezone,
        'allDay': allDay,
        'repeat': repeat.toJson(),
        'progressType': progressType.name,
        'remindersMinBefore': remindersMinBefore,
        'notificationEnabled': notificationEnabled,
        'channel': channel.name,
        'lockVisibility': lockVisibility.name,
        'order': order,
        'parentId': parentId,
        'dependencyIds': dependencyIds,
      };

  factory Plan.fromJson(Map<String, dynamic> json) {
    ProgressType? pt;
    for (final e in ProgressType.values) {
      if (e.name == json['progressType']) pt = e;
    }
    PlanChannel? ch;
    for (final e in PlanChannel.values) {
      if (e.name == json['channel']) ch = e;
    }
    LockScreenVisibility? lv;
    for (final e in LockScreenVisibility.values) {
      if (e.name == json['lockVisibility']) lv = e;
    }
    return Plan(
      id: json['id'] as String,
      title: json['title'] as String,
      type: json['type'] as String? ?? '',
      topic: json['topic'] as String? ?? '',
      unit: json['unit'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      color: (json['color'] as num?)?.toInt() ?? 0xFF3B6EF6,
      iconName: json['iconName'] as String? ?? 'schedule',
      tags: ((json['tags'] as List?) ?? const []).cast<String>(),
      startDate: parseIsoToLocal(json['startDate'] as String),
      duration:
          Duration(minutes: (json['durationMinutes'] as num?)?.toInt() ?? 0),
      timezone: json['timezone'] as String? ?? 'local',
      allDay: json['allDay'] as bool? ?? false,
      repeat: json['repeat'] is Map
          ? RepeatRule.fromJson(json['repeat'] as Map<String, dynamic>)
          : const RepeatRule(),
      progressType: pt ?? ProgressType.automatic,
      remindersMinBefore:
          ((json['remindersMinBefore'] as List?) ?? const [])
              .map((e) => (e as num).toInt())
              .toList(),
      notificationEnabled: json['notificationEnabled'] as bool? ?? true,
      channel: ch ?? PlanChannel.start,
      lockVisibility: lv ?? LockScreenVisibility.public,
      order: (json['order'] as num?)?.toInt() ?? 0,
      parentId: json['parentId'] as String?,
      dependencyIds:
          ((json['dependencyIds'] as List?) ?? const []).cast<String>(),
    );
  }
}

/// 计划实例(某天)的实时运行状态
class PlanRuntime {
  PlanRuntime({
    required this.planId,
    required this.dateKey,
    this.status = PlanStatus.unstarted,
    this.progress = 0,
    this.startedAt,
    this.completedAt,
    this.pauseHistory = const [],
    this.adjustments = const [],
  });

  final String planId;

  /// yyyy-MM-dd
  final String dateKey;
  PlanStatus status;

  /// 0..1(manual 进度类型时用户设置;automatic 时派生)
  double progress;
  DateTime? startedAt;
  DateTime? completedAt;
  List<PauseSegment> pauseHistory;
  List<PlanAdjustment> adjustments;

  /// 累计已完结暂停时长
  Duration get totalPausedDuration => pauseHistory
      .where((s) => s.endedAt != null)
      .fold(Duration.zero, (sum, s) => sum + s.duration);

  /// 当前暂停段的起始(正在暂停时为非空)
  DateTime? get currentPauseStartedAt {
    for (final s in pauseHistory) {
      if (s.endedAt == null) return s.startedAt;
    }
    return null;
  }

  /// 调整累计分钟数(加时正 / 减时负)
  int get adjustmentMinutes =>
      adjustments.fold(0, (sum, a) => sum + a.deltaMinutes);

  PlanRuntime copyWith({
    PlanStatus? status,
    double? progress,
    DateTime? startedAt,
    DateTime? completedAt,
    List<PauseSegment>? pauseHistory,
    List<PlanAdjustment>? adjustments,
  }) {
    return PlanRuntime(
      planId: planId,
      dateKey: dateKey,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      pauseHistory: pauseHistory ?? this.pauseHistory,
      adjustments: adjustments ?? this.adjustments,
    );
  }

  Map<String, dynamic> toJson() => {
        'planId': planId,
        'dateKey': dateKey,
        'status': status.name,
        'progress': progress,
        'startedAt': startedAt?.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'pauseHistory': pauseHistory.map((s) => s.toJson()).toList(),
        'adjustments': adjustments.map((a) => a.toJson()).toList(),
      };

  factory PlanRuntime.fromJson(Map<String, dynamic> json) {
    PlanStatus? st;
    for (final e in PlanStatus.values) {
      if (e.name == json['status']) st = e;
    }
    return PlanRuntime(
      planId: json['planId'] as String,
      dateKey: json['dateKey'] as String,
      status: st ?? PlanStatus.unstarted,
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'] as String)
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      pauseHistory: ((json['pauseHistory'] as List?) ?? const [])
          .map((e) => PauseSegment.fromJson(e as Map<String, dynamic>))
          .toList(),
      adjustments: ((json['adjustments'] as List?) ?? const [])
          .map((e) => PlanAdjustment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

import 'plan.dart';

/// 一次计划执行的历史记录(终结后归档)
class PlanHistoryRecord {
  const PlanHistoryRecord({
    required this.planId,
    required this.dateKey,
    required this.title,
    required this.scheduledStart,
    required this.effectiveEnd,
    required this.finalStatus,
    required this.plannedDuration,
    required this.actualActive,
    required this.interruptionCount,
    this.completedAt,
    this.actualStart,
    this.actualEnd,
  });

  final String planId;
  final String dateKey;
  final String title;
  final DateTime scheduledStart;
  final DateTime effectiveEnd;
  final PlanStatus finalStatus;

  /// 原计划时长
  final Duration plannedDuration;

  /// 实际有效投入时长(去暂停;加时计入)
  final Duration actualActive;

  /// 中断次数 = 暂停段数 + 调整次数
  final int interruptionCount;
  final DateTime? completedAt;

  /// 实际开始时间(实例开始执行的时刻)
  final DateTime? actualStart;

  /// 实际结束时间(完成/超时处理/跳过时的时刻)
  final DateTime? actualEnd;

  Map<String, dynamic> toJson() => {
        'planId': planId,
        'dateKey': dateKey,
        'title': title,
        'scheduledStart': scheduledStart.toIso8601String(),
        'effectiveEnd': effectiveEnd.toIso8601String(),
        'finalStatus': finalStatus.name,
        'plannedDurationMin': plannedDuration.inMinutes,
        'actualActiveMin': actualActive.inMinutes,
        'interruptionCount': interruptionCount,
        'completedAt': completedAt?.toIso8601String(),
        'actualStart': actualStart?.toIso8601String(),
        'actualEnd': actualEnd?.toIso8601String(),
      };

  factory PlanHistoryRecord.fromJson(Map<String, dynamic> json) {
    PlanStatus? st;
    for (final e in PlanStatus.values) {
      if (e.name == json['finalStatus']) st = e;
    }
    return PlanHistoryRecord(
      planId: json['planId'] as String,
      dateKey: json['dateKey'] as String,
      title: json['title'] as String,
      scheduledStart: DateTime.parse(json['scheduledStart'] as String),
      effectiveEnd: DateTime.parse(json['effectiveEnd'] as String),
      finalStatus: st ?? PlanStatus.skipped,
      plannedDuration:
          Duration(minutes: (json['plannedDurationMin'] as num?)?.toInt() ?? 0),
      actualActive:
          Duration(minutes: (json['actualActiveMin'] as num?)?.toInt() ?? 0),
      interruptionCount: (json['interruptionCount'] as num?)?.toInt() ?? 0,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      actualStart: json['actualStart'] != null
          ? DateTime.parse(json['actualStart'] as String)
          : null,
      actualEnd: json['actualEnd'] != null
          ? DateTime.parse(json['actualEnd'] as String)
          : null,
    );
  }
}

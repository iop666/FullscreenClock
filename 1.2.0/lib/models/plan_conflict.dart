import '../utils/plan_time.dart';

/// 冲突类型
enum ConflictType { overlap, endBeforeStart, durationOverLimit }

/// 单条冲突
class ConflictIssue {
  const ConflictIssue({
    required this.type,
    required this.planId,
    this.otherPlanId,
    required this.message,
    required this.blocking,
  });

  final ConflictType type;
  final String planId;
  final String? otherPlanId;
  final String message;

  /// true 时阻止保存;false 时仅提示(如时间重叠)
  final bool blocking;
}

/// 冲突检测结果
class ConflictReport {
  const ConflictReport(this.issues);

  final List<ConflictIssue> issues;

  bool get hasBlocking => issues.any((i) => i.blocking);

  List<String> get messages => issues.map((i) => i.message).toList();
}

/// 对同一批计划实例做冲突检测(新建/修改/拖拽排序后统一入口)
ConflictReport detectConflicts(List<PlanOccurrence> occurrences) {
  final issues = <ConflictIssue>[];
  final list = occurrences.toList()
    ..sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));

  for (final o in list) {
    final start = o.scheduledStart;
    final end = o.scheduledEnd;
    if (!end.isAfter(start)) {
      issues.add(ConflictIssue(
        type: ConflictType.endBeforeStart,
        planId: o.plan.id,
        message: '「${o.plan.title}」的结束时间不晚于开始时间',
        blocking: true,
      ));
    }
    if (o.plan.duration.inMinutes <= 0) {
      issues.add(ConflictIssue(
        type: ConflictType.durationOverLimit,
        planId: o.plan.id,
        message: '「${o.plan.title}」的时长必须大于 0',
        blocking: true,
      ));
    }
  }

  for (var i = 0; i < list.length; i++) {
    for (var j = i + 1; j < list.length; j++) {
      final a = list[i];
      final b = list[j];
      if (a.scheduledEnd.isAfter(b.scheduledStart)) {
        issues.add(ConflictIssue(
          type: ConflictType.overlap,
          planId: a.plan.id,
          otherPlanId: b.plan.id,
          message:
              '「${a.plan.title}」与「${b.plan.title}」时间重叠,不允许同时段有其他计划',
          blocking: true,
        ));
      }
    }
  }
  return ConflictReport(issues);
}

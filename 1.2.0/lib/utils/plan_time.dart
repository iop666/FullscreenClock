import 'dart:math';

import '../models/plan.dart';
import '../models/plan_repeat.dart';

/// 某天的一个计划实例
class PlanOccurrence {
  const PlanOccurrence({
    required this.plan,
    required this.day,
    required this.scheduledStart,
    required this.scheduledEnd,
  });

  final Plan plan;
  final DateTime day;
  final DateTime scheduledStart;
  final DateTime scheduledEnd;

  String get dateKey => formatDateKey(day);
}

/// 生成 yyyy-MM-dd
String formatDateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseDateKey(String key) => DateTime.parse(key);

/// 展开 [from]~[to] 日期范围内所有计划的实例(含两端当天,按开始时间升序)。
/// 供列表本日/本周/本月与时间轴复用。
List<PlanOccurrence> occurrencesInRange(
    List<Plan> plans, DateTime from, DateTime to) {
  final list = <PlanOccurrence>[];
  var d = startOfDay(from);
  final last = startOfDay(to);
  while (!d.isAfter(last)) {
    list.addAll(occurrencesOnDay(plans, d));
    d = d.add(const Duration(days: 1));
  }
  list.sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));
  return list;
}

final Random _idRandom = Random();

/// 生成一个本地唯一 ID(时间戳 + 随机)
String newPlanId() => 'p${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}'
    '${_idRandom.nextInt(0xFFFFFF).toRadixString(16)}';

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime endOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59);

/// 计算给定日期的计划实例;若该日不命中重复规则则返回 null。
PlanOccurrence? occurrenceOn(Plan plan, DateTime day) {
  if (plan.duration.inMinutes <= 0) return null;
  if (!_withinRepeat(plan, day)) return null;
  final start = plan.occurrenceStart(day);
  return PlanOccurrence(
    plan: plan,
    day: day,
    scheduledStart: start,
    scheduledEnd: start.add(plan.duration),
  );
}

/// 展开某一天所有计划的实例(按开始时间排序)
List<PlanOccurrence> occurrencesOnDay(
    List<Plan> plans, DateTime day) {
  final list = <PlanOccurrence>[];
  for (final p in plans) {
    final o = occurrenceOn(p, day);
    if (o != null) list.add(o);
  }
  list.sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));
  return list;
}

/// 找首个在 [after] 之后的实例(用于"下一计划"倒计时)
PlanOccurrence? nextOccurrence(List<Plan> plans, DateTime after) {
  final day = startOfDay(after);
  PlanOccurrence? best;
  for (final p in plans) {
    // 从 after 所在日开始,至多找 repeatCount*interval 或 366 天
    final maxDay = _repeatMaxDay(p);
    for (var d = day;
        !d.isAfter(maxDay);
        d = d.add(const Duration(days: 1))) {
      final o = occurrenceOn(p, d);
      if (o == null) continue;
      if (o.scheduledStart.isAfter(after)) {
        if (best == null || o.scheduledStart.isBefore(best.scheduledStart)) {
          best = o;
        }
        break; // 该计划首个满足的即可
      }
    }
  }
  return best;
}

/// 实例的有效结束时间:
/// 原定结束 + 累计暂停 + 当前暂停已流逝 + 加/减时调整(暂停顺延 + 加减时)
DateTime effectiveEnd(PlanOccurrence o, PlanRuntime rt, DateTime now) {
  final base = o.scheduledEnd;
  var extra = rt.totalPausedDuration;
  final open = rt.currentPauseStartedAt;
  if (open != null) {
    extra = extra + now.difference(open);
  }
  extra = extra + Duration(minutes: rt.adjustmentMinutes);
  return base.add(extra);
}

bool _withinRepeat(Plan plan, DateTime day) {
  final r = plan.repeat;
  if (r.frequency == PlanRepeatFrequency.none) {
    return sameDay(day, plan.startDate);
  }
  final anchor = startOfDay(plan.startDate);
  if (day.isBefore(anchor)) return false;
  if (!r.matches(day)) return false;
  if (!r.inInterval(plan.startDate, day)) return false;
  if (r.endType == RepeatEndCondition.until && r.untilDate != null) {
    if (day.isAfter(endOfDay(r.untilDate!))) return false;
  }
  if (r.endType == RepeatEndCondition.count && r.repeatCount != null) {
    final maxDay = _repeatMaxDay(plan);
    if (day.isAfter(maxDay)) return false;
    var count = 0;
    for (var d = anchor; !d.isAfter(day); d = d.add(const Duration(days: 1))) {
      if (r.matches(d) && r.inInterval(plan.startDate, d)) {
        count++;
        if (count > r.repeatCount!) return false;
      }
    }
    if (count == 0) return false;
  }
  return true;
}

/// 重复计划可能发生的最后一天(用于停止迭代)
DateTime _repeatMaxDay(Plan plan) {
  final r = plan.repeat;
  final anchor = startOfDay(plan.startDate);
  if (r.frequency == PlanRepeatFrequency.none) return anchor;
  if (r.endType == RepeatEndCondition.until && r.untilDate != null) {
    return endOfDay(r.untilDate!);
  }
  if (r.endType == RepeatEndCondition.count && r.repeatCount != null) {
    // 保守上限:interval 步长 × count 天(逐日)与 31(月)的最大跨度
    final n = r.repeatCount!;
    final stepDays = r.interval *
        switch (r.frequency) {
          PlanRepeatFrequency.daily => 1,
          PlanRepeatFrequency.weekly => 7,
          PlanRepeatFrequency.workdays => 7,
          PlanRepeatFrequency.monthly => 31,
          PlanRepeatFrequency.none => 1,
        };
    return anchor.add(Duration(days: n * stepDays + 31));
  }
  // never:给一个合理上限(10 年)防无限迭代
  return anchor.add(const Duration(days: 3660));
}

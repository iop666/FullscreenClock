import 'package:flutter/foundation.dart';

/// 重复频率
enum PlanRepeatFrequency { none, daily, weekly, workdays, monthly }

/// 重复结束条件
enum RepeatEndCondition { never, until, count }

/// 重复规则(计划展开为多天实例的调度定义)
@immutable
class RepeatRule {
  const RepeatRule({
    this.frequency = PlanRepeatFrequency.none,
    this.interval = 1,
    this.daysOfWeek = const [],
    this.daysOfMonth = const [],
    this.endType = RepeatEndCondition.never,
    this.untilDate,
    this.repeatCount,
  });

  final PlanRepeatFrequency frequency;
  final int interval;

  /// 每周重复时:1=周一 ... 7=周日
  final List<int> daysOfWeek;

  /// 每月重复时:1..31(负值表示从月末倒数,-1=最后一天)
  final List<int> daysOfMonth;

  final RepeatEndCondition endType;
  final DateTime? untilDate;
  final int? repeatCount;

  /// 工作日 = 周一至周五
  static const List<int> workdays = [1, 2, 3, 4, 5];

  /// 判断给定日期(该日的星期几用 [weekday] 传入,1=周一)是否命中此规则
  bool matches(DateTime day) {
    switch (frequency) {
      case PlanRepeatFrequency.none:
        return true;
      case PlanRepeatFrequency.daily:
        return true;
      case PlanRepeatFrequency.weekly:
        return daysOfWeek.contains(day.weekday);
      case PlanRepeatFrequency.workdays:
        return workdays.contains(day.weekday);
      case PlanRepeatFrequency.monthly:
        if (daysOfMonth.isEmpty) return true;
        final last = DateTime(day.year, day.month + 1, 0).day;
        return daysOfMonth.any((d) {
          final target = d < 0 ? last + d + 1 : d;
          return day.day == target;
        });
    }
  }

  /// 判定两个锚定日期的"周数差"或"月数差"是否符合 interval
  bool inInterval(DateTime anchor, DateTime day) {
    switch (frequency) {
      case PlanRepeatFrequency.none:
        return true;
      case PlanRepeatFrequency.daily:
        return day.difference(anchor).inDays % interval == 0;
      case PlanRepeatFrequency.weekly:
      case PlanRepeatFrequency.workdays:
        return weeksBetween(anchor, day) % interval == 0;
      case PlanRepeatFrequency.monthly:
        return monthsBetween(anchor, day) % interval == 0;
    }
  }

  static int weeksBetween(DateTime a, DateTime b) {
    final da = DateTime(a.year, a.month, a.day);
    final db = DateTime(b.year, b.month, b.day);
    return db.difference(da).inDays ~/ 7;
  }

  static int monthsBetween(DateTime a, DateTime b) {
    return (b.year - a.year) * 12 + (b.month - a.month);
  }

  RepeatRule copyWith({
    PlanRepeatFrequency? frequency,
    int? interval,
    List<int>? daysOfWeek,
    List<int>? daysOfMonth,
    RepeatEndCondition? endType,
    DateTime? untilDate,
    int? repeatCount,
  }) {
    return RepeatRule(
      frequency: frequency ?? this.frequency,
      interval: interval ?? this.interval,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      daysOfMonth: daysOfMonth ?? this.daysOfMonth,
      endType: endType ?? this.endType,
      untilDate: untilDate ?? this.untilDate,
      repeatCount: repeatCount ?? this.repeatCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'frequency': frequency.name,
        'interval': interval,
        'daysOfWeek': daysOfWeek,
        'daysOfMonth': daysOfMonth,
        'endType': endType.name,
        'untilDate': untilDate?.toIso8601String(),
        'repeatCount': repeatCount,
      };

  factory RepeatRule.fromJson(Map<String, dynamic> json) {
    PlanRepeatFrequency? freq;
    for (final f in PlanRepeatFrequency.values) {
      if (f.name == json['frequency']) freq = f;
    }
    RepeatEndCondition? end;
    for (final e in RepeatEndCondition.values) {
      if (e.name == json['endType']) end = e;
    }
    return RepeatRule(
      frequency: freq ?? PlanRepeatFrequency.none,
      interval: (json['interval'] as num?)?.toInt() ?? 1,
      daysOfWeek: ((json['daysOfWeek'] as List?) ?? const [])
          .map((e) => (e as num).toInt())
          .toList(),
      daysOfMonth: ((json['daysOfMonth'] as List?) ?? const [])
          .map((e) => (e as num).toInt())
          .toList(),
      endType: end ?? RepeatEndCondition.never,
      untilDate: json['untilDate'] != null
          ? DateTime.tryParse(json['untilDate'] as String)
          : null,
      repeatCount: (json['repeatCount'] as num?)?.toInt(),
    );
  }
}

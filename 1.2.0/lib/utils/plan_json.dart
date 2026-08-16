import 'dart:convert';

import '../models/plan.dart';
import '../models/plan_repeat.dart';

/// 导入校验结果
class ImportReport {
  const ImportReport({this.errors = const [], this.warnings = const []});

  final List<String> errors;
  final List<String> warnings;

  bool get hasErrors => errors.isNotEmpty;
}

/// 导出/导入的 Schema 版本(供向后兼容)
const String kPlanSchemaVersion = '1.0.0';

/// 构建导出 JSON(顶层按 Schema:版本/时间/应用版本/元数据/plans)
/// [runtimes] 提供每个计划最新实例状态,合并进对应条目。
Map<String, dynamic> buildExportJson(
  List<Plan> plans,
  Map<String, PlanRuntime> runtimes,
  DateTime exportedAt, {
  String appVersion = '',
  Map<String, dynamic>? metadata,
}) {
  return {
    'schemaVersion': kPlanSchemaVersion,
    'exportedAt': exportedAt.toIso8601String(),
    'appVersion': appVersion,
    'metadata': metadata ?? {},
    'plans': [
      for (final p in plans) _planToExportJson(p, runtimes[p.id]),
    ],
  };
}

Map<String, dynamic> _planToExportJson(Plan p, PlanRuntime? rt) {
  final json = p.toJson();
  if (rt != null) {
    json['status'] = rt.status.name;
    json['progress'] = rt.progress;
    json['startedAt'] = rt.startedAt?.toIso8601String();
    json['completedAt'] = rt.completedAt?.toIso8601String();
    json['pauseHistory'] = rt.pauseHistory.map((s) => s.toJson()).toList();
    json['totalPausedDuration'] = rt.totalPausedDuration.inSeconds;
    json['adjustments'] = rt.adjustments.map((a) => a.toJson()).toList();
    json['effectiveDuration'] =
        p.duration.inMinutes + rt.adjustmentMinutes;
  }
  return json;
}

/// 校验导入的 JSON 对象,返回错误/警告报告(只读,不修改)。
ImportReport validateImport(Map<String, dynamic>? root) {
  if (root == null) {
    return const ImportReport(errors: ['文件不是有效的 JSON 对象']);
  }
  final errors = <String>[];
  final warnings = <String>[];

  final schema = root['schemaVersion'];
  if (schema is! String || schema.isEmpty) {
    errors.add('缺少或无效的 schemaVersion 字段');
  } else {
    warnings.add('数据格式版本: $schema');
  }

  final plans = root['plans'];
  if (plans is! List || plans.isEmpty) {
    return ImportReport(errors: [...errors, 'plans 必须是非空数组']);
  }

  final seenIds = <String>{};
  var index = 0;
  for (final raw in plans) {
    index++;
    final label = '第 $index 条计划';
    if (raw is! Map) {
      errors.add('$label: 不是对象');
      continue;
    }
    final m = raw.cast<String, dynamic>();

    // 必填字段
    if (m['id'] is! String || (m['id'] as String).isEmpty) {
      errors.add('$label: 缺少必填字段 id');
    } else if (!seenIds.add(m['id'] as String)) {
      errors.add('$label: id「${m['id']}」重复');
    }
    if (m['title'] is! String || (m['title'] as String).trim().isEmpty) {
      errors.add('$label: 缺少必填字段 title');
    }

    // 时间格式
    final start = m['startDate'];
    if (start is String && DateTime.tryParse(start) != null) {
      // ok
    } else {
      errors.add('$label: startDate 缺失或不是有效时间');
    }

    // 时长:durationMinutes 或 endTime 推导
    final dur = m['durationMinutes'];
    if (dur is num && dur.toInt() > 0) {
      // ok
    } else if (m['endTime'] is String &&
        DateTime.tryParse(m['endTime'] as String) != null &&
        start is String &&
        DateTime.tryParse(start) != null) {
      // endTime 推导(不校验具体值)
    } else {
      errors.add('$label: durationMinutes 必须为正数(或提供有效 endTime)');
    }

    // 状态合法
    final st = m['status'];
    if (st is String &&
        !PlanStatus.values.any((e) => e.name == st)) {
      errors.add('$label: status「$st」不合法');
    }

    // 重复规则结构
    final rep = m['repeat'];
    if (rep is Map) {
      final freq = rep['frequency'];
      if (freq is String &&
          !PlanRepeatFrequency.values.any((e) => e.name == freq)) {
        errors.add('$label: repeat.frequency「$freq」不合法');
      }
      final endType = rep['endType'];
      if (endType is String &&
          !RepeatEndCondition.values.any((e) => e.name == endType)) {
        errors.add('$label: repeat.endType「$endType」不合法');
      }
    }
  }

  return ImportReport(errors: errors, warnings: warnings);
}

/// 从导入的 JSON 解析出 Plan 列表(校验通过后调用;跳过不合法条目)
/// 返回 (plans, warnings),错误条目以 warning 形式给出但跳过。
({List<Plan> plans, List<String> warnings}) parseImportedPlans(
    Map<String, dynamic> root) {
  final plans = <Plan>[];
  final warnings = <String>[];
  final rawPlans = root['plans'];
  if (rawPlans is! List) return (plans: plans, warnings: warnings);
  var index = 0;
  for (final raw in rawPlans) {
    index++;
    if (raw is! Map) continue;
    try {
      final m = raw.cast<String, dynamic>();
      // 兼容:endTime 推导 durationMinutes
      if (m['durationMinutes'] == null && m['endTime'] is String) {
        final start = parseIsoToLocal(m['startDate'] as String);
        final end = parseIsoToLocal(m['endTime'] as String);
        if (end.isAfter(start)) {
          m['durationMinutes'] = end.difference(start).inMinutes;
        }
      }
      plans.add(Plan.fromJson(m));
    } catch (e) {
      warnings.add('第 $index 条计划解析失败,已跳过: $e');
    }
  }
  return (plans: plans, warnings: warnings);
}

/// 序列化导出 JSON 字符串
String encodeExportJson(Map<String, dynamic> json) =>
    const JsonEncoder.withIndent('  ').convert(json);

/// 从字符串解码(失败返回 null)
Map<String, dynamic>? decodeExportJson(String text) {
  try {
    final v = jsonDecode(text);
    return v is Map ? v.cast<String, dynamic>() : null;
  } catch (_) {
    return null;
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';

import '../providers/plan_provider.dart';
import '../utils/plan_json.dart';

/// 计划 JSON 导入导出(file_selector 选文件)。
class PlanExportService {
  PlanExportService._();

  static const XTypeGroup _jsonType =
      XTypeGroup(label: 'JSON', extensions: ['json']);

  static String _fileName() {
    final d = DateTime.now();
    return 'fullscreen_clock_plans_${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}.json';
  }

  /// 导出当前计划到用户选择的文件;返回路径(取消/失败返回 null)。
  static Future<String?> exportToFile(PlanProvider p) async {
    final root = buildExportJson(
      p.plans,
      p.runtimes,
      DateTime.now(),
      metadata: const {'exportSource': 'fullscreen-clock-app'},
    );
    return saveTextToUserLocation(encodeExportJson(root));
  }

  /// 把任意文本保存为 JSON 文件;返回保存位置(取消/失败返回 null)。
  /// Android:原生 SAF 保存对话框——先生成 JSON 内容,用户选择保存位置后写入。
  /// Windows:file_selector 弹保存对话框。
  static Future<String?> saveTextToUserLocation(String content,
      {String? suggestedName}) async {
    final name = suggestedName ?? _fileName();
    if (Platform.isAndroid) {
      try {
        const channel = MethodChannel('fullscreenclock/plan');
        final path = await channel.invokeMethod<String>('pickSaveLocation', {
          'fileName': name,
          'content': content,
        });
        return path;
      } catch (_) {
        return null;
      }
    }
    try {
      final loc = await getSaveLocation(
        suggestedName: name,
        acceptedTypeGroups: const [_jsonType],
      );
      if (loc == null) return null;
      await File(loc.path).writeAsString(content, encoding: utf8);
      return loc.path;
    } catch (_) {
      return null;
    }
  }

  /// 读取用户选择的 JSON 文件;返回 (路径, 内容)。
  static Future<({String path, String content})?> pickJsonFile() async {
    final file = await openFile(acceptedTypeGroups: const [_jsonType]);
    if (file == null) return null;
    final content = await file.readAsString();
    return (path: file.path, content: content);
  }

  /// 导入:校验 → 追加。返回报告;校验失败不修改数据。
  static ImportReport importContent(PlanProvider p, String content) {
    final root = decodeExportJson(content);
    if (root == null) {
      return const ImportReport(errors: ['文件不是有效的 JSON 对象']);
    }
    final report = validateImport(root);
    if (report.hasErrors) return report;
    final parsed = parseImportedPlans(root);
    final warnings = [...parsed.warnings];
    for (final plan in parsed.plans) {
      final err = p.addPlan(plan);
      if (err != null) warnings.add(err);
    }
    return ImportReport(warnings: warnings);
  }

  /// 计划中是否含有备注/标签(用于导出前的隐私提示)
  static bool hasSensitiveContent(PlanProvider p) =>
      p.plans.any((plan) => plan.notes.isNotEmpty || plan.tags.isNotEmpty);
}

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/plan_provider.dart';
import '../utils/plan_json.dart';

/// 本地自动备份:按周期(默认 24h)把计划 JSON 备份到
/// 文档目录 plans_backup/,保留最近 7 份。
class PlanBackupService {
  PlanBackupService._();

  static const _kLastKey = 'plan_backup_last';
  static const Duration _interval = Duration(hours: 24);
  static const int _keepCount = 7;

  /// 启动时调用:距上次备份超过周期才备份
  static Future<void> maybeBackup(PlanProvider p) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getString(_kLastKey);
      if (last != null) {
        final t = DateTime.tryParse(last);
        if (t != null &&
            DateTime.now().difference(t).inHours < _interval.inHours) {
          return;
        }
      }
      final file = await backup(p);
      if (file != null) {
        await prefs.setString(_kLastKey, DateTime.now().toIso8601String());
      }
    } catch (_) {
      // 备份失败静默忽略
    }
  }

  /// 立即备份,返回文件(失败返回 null)
  static Future<File?> backup(PlanProvider p) async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}${Platform.pathSeparator}plans_backup');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final root = buildExportJson(p.plans, p.runtimes, DateTime.now());
      final file =
          File('${dir.path}${Platform.pathSeparator}plans_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(encodeExportJson(root), encoding: utf8);
      // 保留最近 N 份
      final files = dir
          .listSync()
          .whereType<File>()
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));
      for (final f in files.skip(_keepCount)) {
        try {
          f.deleteSync();
        } catch (_) {}
      }
      return file;
    } catch (_) {
      return null;
    }
  }
}

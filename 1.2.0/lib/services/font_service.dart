import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// 运行时导入自定义字体:选择 .ttf/.otf → 复制到应用目录 → FontLoader 注册
class FontService {
  FontService._();

  /// 固定使用该字体族名注册,便于设置与切换
  static const customFamily = 'CustomFont';

  /// 弹出文件选择器导入字体,成功返回字体族名
  static Future<String?> pickAndInstallFont() async {
    try {
      const typeGroup = XTypeGroup(
        label: '字体',
        extensions: ['ttf', 'otf'],
        uniformTypeIdentifiers: ['public.font', 'com.adobe.postscript-font'],
      );
      final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null) return null;
      final path = file.path;
      if (path.isEmpty) return null;

      final dir = await getApplicationDocumentsDirectory();
      final ext = path.split('.').last.toLowerCase();
      final dest = '${dir.path}/fonts/$customFamily.$ext';
      final destFile = File(dest);
      await destFile.parent.create(recursive: true);
      await File(path).copy(dest);
      await _loadFromFile(dest, customFamily);
      return customFamily;
    } catch (_) {
      return null;
    }
  }

  /// 应用启动时加载已导入的字体(从持久化目录)
  static Future<void> loadInstalledFont() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final fontsDir = Directory('${dir.path}/fonts');
      if (!await fontsDir.exists()) return;
      await for (final entry in fontsDir.list()) {
        final p = entry.path.toLowerCase();
        if (entry is File && (p.endsWith('.ttf') || p.endsWith('.otf'))) {
          await _loadFromFile(entry.path, customFamily);
          return;
        }
      }
    } catch (_) {}
  }

  static Future<void> _loadFromFile(String path, String family) async {
    final bytes = await File(path).readAsBytes();
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
}

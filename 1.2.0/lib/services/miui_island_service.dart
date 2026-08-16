import 'dart:convert';

import '../models/plan.dart';
import '../utils/plan_time.dart';
import 'plan_alarm_service.dart';

/// 小米 HyperOS 超级岛/焦点通知(预留)。
/// 接入需平台准入(开发者认证 + 场景预审 + 方案审核 + 白名单联调 + 上线验证),
/// 本服务仅提供能力探测与参数封装,默认不启用岛通知。
class MiuiIslandService {
  MiuiIslandService._();

  /// 是否启用岛通知(默认 false,待平台准入后开启)
  static bool enabled = false;

  static Future<bool> isSupported() => PlanAlarmService.isMiuiIslandSupported();

  /// 根据设备品牌返回灵动岛名称(品牌兼容)
  static String? islandNameForBrand(String? brand) {
    final b = brand?.toLowerCase() ?? '';
    if (b.contains('xiaomi') || b.contains('redmi') || b.contains('poco')) {
      return '超级岛';
    }
    if (b.contains('huawei')) return '实况窗';
    if (b.contains('vivo') || b.contains('iqoo')) return '原子岛';
    if (b.contains('oppo') || b.contains('oneplus') || b.contains('realme')) {
      return '流体云';
    }
    if (b.contains('honor')) return '灵动胶囊';
    return null;
  }

  /// 构建 miui.focus.param 的 param_v2 JSON(预留;准入后调用)。
  /// 说明:超长/多图/动作按钮等高级字段按官方模板约束,这里提供基础结构。
  static String buildIslandParams({
    required String business,
    required String title,
    required String content,
    String? aodTitle,
    String highlightColor = '#3B6EF6',
  }) {
    final map = {
      'param_v2': {
        'protocol': 1,
        'business': business,
        'enableFloat': true,
        'updatable': true,
        'aodTitle': aodTitle ?? title,
        'baseInfo': {
          'title': title,
          'content': content,
          'colorTitle': highlightColor,
          'type': 2,
        },
        'param_island': {
          'islandProperty': 1,
          'islandOrder': 0,
          'bigIslandArea': {
            'imageTextInfoLeft': {
              'type': 1,
              'textInfo': {
                'frontTitle': title,
                'title': content,
                'content': '',
                'useHighLight': false,
              },
            },
          },
          'smallIslandArea': {'textInfo': {'title': title, 'content': content}},
        },
      },
    };
    return jsonEncode(map);
  }

  /// 将通知 extras 中的 miui.focus.param 拼接(预留,需原生 Notification 支持)
  static void attachToNotification(
    Plan plan,
    PlanOccurrence occ,
    DateTime now,
  ) {
    // 预留:当 enabled 且平台支持时,由原生 PlanNotifier 在通知上附加
  }
}

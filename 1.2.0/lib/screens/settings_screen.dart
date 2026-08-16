import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/clock_settings.dart';
import '../providers/plan_provider.dart';
import '../providers/settings_provider.dart';
import '../services/font_service.dart';
import '../theme/app_theme.dart';
import '../widgets/plan_notification_settings_sheet.dart';
import 'plan_candidates_screen.dart';
import 'plan_list_screen.dart';
import 'plan_stats_screen.dart';

/// 设置页:与时钟显示页分离,所有设置实时持久化
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.provider,
    required this.planProvider,
  });

  final SettingsProvider provider;
  final PlanProvider planProvider;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([provider, planProvider]),
      builder: (context, _) {
        final settings = provider.settings;
        final palette =
            resolvePalette(settings, MediaQuery.platformBrightnessOf(context));

        return Scaffold(
          backgroundColor: palette.background,
          appBar: AppBar(
            backgroundColor: palette.background,
            foregroundColor: palette.foreground,
            elevation: 0,
            title: const Text('设置'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _groupTitle(palette, '外观'),
              _card(
                palette,
                child: Column(
                  children: [
                    _optionRow(
                      palette,
                      title: '明暗模式',
                      child: _segmented<ClockTheme>(
                        palette,
                        values: ClockTheme.values,
                        selected: settings.theme,
                        labelOf: _themeLabel,
                        onChanged: provider.setTheme,
                      ),
                    ),
                    _divider(palette),
                    _optionRow(
                      palette,
                      title: '主题配色方案',
                      child: _paletteSection(settings, context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _groupTitle(palette, '显示设置'),
              _card(
                palette,
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.access_time, color: palette.accent),
                      title: Text('时钟显示设置', style: _label(palette)),
                      subtitle: Text(
                        '时钟样式、标准与圆盘参数、时间格式',
                        style: TextStyle(color: palette.secondary, fontSize: 12),
                      ),
                      trailing: Icon(Icons.chevron_right, color: palette.secondary),
                      onTap: () => _openClockDisplay(context, palette),
                    ),
                    _divider(palette),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading:
                          Icon(Icons.dashboard_customize_outlined, color: palette.accent),
                      title: Text('计划显示设置', style: _label(palette)),
                      subtitle: Text(
                        '计划模块参数设置',
                        style: TextStyle(color: palette.secondary, fontSize: 12),
                      ),
                      trailing: Icon(Icons.chevron_right, color: palette.secondary),
                      onTap: () => _openPlanDisplay(context, palette),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _groupTitle(palette, '计划'),
              _card(
                palette,
                child: Column(
                  children: [
                    _switchTile(
                      palette,
                      title: '启用计划功能',
                      subtitle: '创建计划、到点提醒与统计',
                      value: planProvider.enabled,
                      onChanged: planProvider.setEnabled,
                    ),
                    _divider(palette),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.playlist_play, color: palette.accent),
                      title: Text('计划列表', style: _label(palette)),
                      subtitle: Text(
                        '新建、编辑、排序与删除计划',
                        style: TextStyle(color: palette.secondary, fontSize: 12),
                      ),
                      trailing: Icon(Icons.chevron_right, color: palette.secondary),
                      onTap: () => _openPlanList(context),
                    ),
                    _divider(palette),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.bookmark_outline, color: palette.accent),
                      title: Text('候选清单', style: _label(palette)),
                      subtitle: Text(
                        '类型›主题›单元›标题,可导入导出与筛选管理',
                        style: TextStyle(color: palette.secondary, fontSize: 12),
                      ),
                      trailing: Icon(Icons.chevron_right, color: palette.secondary),
                      onTap: () => _openCandidates(context),
                    ),
                    _divider(palette),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.notifications_outlined, color: palette.accent),
                      title: Text('通知设置', style: _label(palette)),
                      subtitle: Text(
                        '提前提醒、后台权限',
                        style: TextStyle(color: palette.secondary, fontSize: 12),
                      ),
                      trailing: Icon(Icons.chevron_right, color: palette.secondary),
                      onTap: () => _openNotificationSettings(context, palette),
                    ),
                    _divider(palette),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.bar_chart_outlined, color: palette.accent),
                      title: Text('统计与历史', style: _label(palette)),
                      subtitle: Text(
                        '完成率、实际时长对比与历史记录',
                        style: TextStyle(color: palette.secondary, fontSize: 12),
                      ),
                      trailing: Icon(Icons.chevron_right, color: palette.secondary),
                      onTap: () => _openStats(context),
                    ),
                    _divider(palette),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.smart_toy_outlined, color: palette.accent),
                      title: Text('计划生成帮助', style: _label(palette)),
                      subtitle: Text(
                        '借助 AI 生成计划或计划结构清单',
                        style: TextStyle(color: palette.secondary, fontSize: 12),
                      ),
                      trailing: Icon(Icons.chevron_right, color: palette.secondary),
                      onTap: () => _openPlanHelp(context, palette),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _groupTitle(palette, '其他'),
              _card(
                palette,
                child: Column(
                  children: [
                    _switchTile(
                      palette,
                      title: '保持屏幕常亮',
                      subtitle: '显示时钟时屏幕不会熄灭',
                      value: settings.keepAwake,
                      onChanged: provider.setKeepAwake,
                    ),
                    _divider(palette),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.palette_outlined, color: palette.accent),
                      title: Text('配色参考', style: _label(palette)),
                      subtitle: Text(
                        'https://zhongguose.com/ 中国传统色',
                        style: TextStyle(color: palette.secondary, fontSize: 12),
                      ),
                      trailing: Icon(Icons.open_in_new, color: palette.secondary, size: 18),
                      onTap: () => _openUrl('https://zhongguose.com/', context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _groupTitle(palette, '关于'),
              _card(
                palette,
                child: FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snap) {
                    final version = snap.data?.version ?? '1.0.0';
                    return Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.info_outline, color: palette.accent),
                          title: Text('当前版本', style: _label(palette)),
                          subtitle: Text(
                            'v$version',
                            style: TextStyle(color: palette.secondary, fontSize: 12),
                          ),
                        ),
                        _divider(palette),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.code, color: palette.accent),
                          title: Text('GitHub', style: _label(palette)),
                          subtitle: Text(
                            'https://github.com/iop666/FullscreenClock',
                            style: TextStyle(color: palette.secondary, fontSize: 12),
                          ),
                          trailing: Icon(Icons.open_in_new, color: palette.secondary, size: 18),
                          onTap: () =>
                              _openUrl('https://github.com/iop666/FullscreenClock', context),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 28),
              Center(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.accent,
                    side: BorderSide(color: palette.accent),
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  ),
                  onPressed: () => _confirmReset(context, palette),
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('恢复默认设置'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openClockDisplay(BuildContext context, Palette palette) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => _clockDisplayPage(context, palette),
    ));
  }

  void _openPlanDisplay(BuildContext context, Palette palette) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => _planDisplayPage(context, palette),
    ));
  }

  /// 时钟显示设置(二级):时钟显示样式 / 标准时钟参数设置 / 圆盘时钟参数设置
  Widget _clockDisplayPage(BuildContext context, Palette palette) {
    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        final settings = provider.settings;
        final pal = resolvePalette(
            settings, MediaQuery.platformBrightnessOf(context));
        return Scaffold(
          backgroundColor: pal.background,
          appBar: AppBar(
            backgroundColor: pal.background,
            foregroundColor: pal.foreground,
            elevation: 0,
            title: Text('时钟显示设置',
                style: TextStyle(color: pal.foreground)),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _groupTitle(pal, '时钟显示样式'),
              _card(
                pal,
                child: _optionRow(
                  pal,
                  title: '时钟模式',
                  child: _segmented<ClockMode>(
                    pal,
                    values: ClockMode.values,
                    selected: settings.mode,
                    labelOf: _modeLabel,
                    onChanged: provider.setMode,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _groupTitle(pal, '标准时钟参数设置'),
              _card(
                pal,
                child: Column(
                  children: [
                    _optionRow(
                      pal,
                      title: '字体',
                      child: _fontSection(settings, pal),
                    ),
                    _divider(pal),
                    _optionRow(
                      pal,
                      title: '字体颜色',
                      child: _fontColorSection(settings, pal),
                    ),
                    _divider(pal),
                    _optionRow(
                      pal,
                      title: '背景颜色',
                      child: _bgColorSection(settings, pal),
                    ),
                    _divider(pal),
                    _ScaleSliderRow(
                      title: '字体粗细',
                      value: settings.fontWeight.toDouble(),
                      min: 100,
                      max: 900,
                      showPercent: false,
                      palette: pal,
                      onChanged: (v) => provider.setFontWeight(v.round()),
                    ),
                    _divider(pal),
                    _ScaleSliderRow(
                      title: '时钟缩放',
                      value: settings.fontScale,
                      min: 0.1,
                      max: 10.0,
                      showPercent: true,
                      palette: pal,
                      onChanged: provider.setFontScale,
                    ),
                    _divider(pal),
                    _switchTile(
                      pal,
                      title: '使用 24 小时制',
                      subtitle: '关闭后显示 12 小时制(AM/PM)',
                      value: settings.use24Hour,
                      onChanged: provider.setUse24Hour,
                    ),
                    _divider(pal),
                    _switchTile(
                      pal,
                      title: '显示秒',
                      subtitle: '在时间中显示秒',
                      value: settings.showSeconds,
                      onChanged: provider.setShowSeconds,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _groupTitle(pal, '圆盘时钟参数设置'),
              _card(
                pal,
                child: Column(
                  children: [
                    _optionRow(
                      pal,
                      title: '表盘样式',
                      child: _segmented<AnalogClockStyle>(
                        pal,
                        values: AnalogClockStyle.values,
                        selected: settings.analogStyle,
                        labelOf: _analogLabel,
                        onChanged: provider.setAnalogStyle,
                      ),
                    ),
                    _divider(pal),
                    _ScaleSliderRow(
                      title: '圆盘缩放',
                      value: settings.analogScale,
                      min: 0.1,
                      max: 3.0,
                      showPercent: true,
                      palette: pal,
                      onChanged: provider.setAnalogScale,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 计划显示设置(二级):计划模块参数设置
  Widget _planDisplayPage(BuildContext context, Palette palette) {
    return ListenableBuilder(
      listenable: Listenable.merge([provider, planProvider]),
      builder: (context, _) {
        final settings = provider.settings;
        final pal = resolvePalette(
            settings, MediaQuery.platformBrightnessOf(context));
        return Scaffold(
          backgroundColor: pal.background,
          appBar: AppBar(
            backgroundColor: pal.background,
            foregroundColor: pal.foreground,
            elevation: 0,
            title: Text('计划显示设置',
                style: TextStyle(color: pal.foreground)),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _groupTitle(pal, '计划模块参数设置'),
              _card(
                pal,
                child: Column(
                  children: [
                    _optionRow(
                      pal,
                      title: '布局模式',
                      child: _moduleSplitSegmented(pal),
                    ),
                    _divider(pal),
                    _optionRow(
                      pal,
                      title: '模块位置',
                      child: _moduleAlignSegmented(pal),
                    ),
                    _divider(pal),
                    _optionRow(
                      pal,
                      title: '显示内容',
                      child: _moduleTimeSegmented(pal),
                    ),
                    _divider(pal),
                    _switchTile(
                      pal,
                      title: '显示进度环',
                      subtitle: '计划模块显示进度环',
                      value: planProvider.moduleShowProgress,
                      onChanged: planProvider.setModuleShowProgress,
                    ),
                    _divider(pal),
                    _switchTile(
                      pal,
                      title: '显示计划颜色',
                      subtitle: '进度环前显示计划颜色条',
                      value: planProvider.moduleShowColor,
                      onChanged: planProvider.setModuleShowColor,
                    ),
                    _divider(pal),
                    _ScaleSliderRow(
                      title: '计划模块缩放',
                      value: planProvider.overlayScale,
                      min: 0.5,
                      max: 2.0,
                      showPercent: true,
                      palette: pal,
                      onChanged: planProvider.setOverlayScale,
                    ),
                    _divider(pal),
                    _switchTile(
                      pal,
                      title: '显示计划图标',
                      subtitle: '计划模块中显示计划图标',
                      value: planProvider.moduleShowIcon,
                      onChanged: planProvider.setModuleShowIcon,
                    ),
                    _divider(pal),
                    _switchTile(
                      pal,
                      title: '计划图标颜色使用计划设置颜色',
                      subtitle: '开启后图标自动使用计划颜色',
                      value: planProvider.moduleIconPlanColor,
                      onChanged: planProvider.setModuleIconPlanColor,
                    ),
                    _divider(pal),
                    _switchTile(
                      pal,
                      title: '进行中描边用计划颜色',
                      subtitle: '默认使用主题强调色,开启后使用计划颜色',
                      value: planProvider.moduleStrokePlanColor,
                      onChanged: planProvider.setModuleStrokePlanColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openCandidates(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PlanCandidatesScreen(
        planProvider: planProvider,
        palette: resolvePalette(
            provider.settings, MediaQuery.platformBrightnessOf(context)),
      ),
    ));
  }

  void _openPlanList(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlanListScreen(
          planProvider: planProvider,
          palette: resolvePalette(
              provider.settings, MediaQuery.platformBrightnessOf(context)),
        ),
      ),
    );
  }

  void _openStats(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlanStatsScreen(
          planProvider: planProvider,
          palette: resolvePalette(
              provider.settings, MediaQuery.platformBrightnessOf(context)),
        ),
      ),
    );
  }

  Widget _moduleAlignSegmented(Palette palette) => _segmented<String>(
        palette,
        values: const ['center', 'bottomLeft', 'bottomRight', 'stretch'],
        selected: planProvider.moduleAlign,
        labelOf: (v) => switch (v) {
          'center' => '居中',
          'bottomLeft' => '靠左下',
          'bottomRight' => '靠右下',
          'stretch' => '两端',
          _ => v,
        },
        // 仅「底部横条」布局可选;时钟靠左+计划靠右时禁用
        enabled: !planProvider.moduleSplit,
        onChanged: planProvider.setModuleAlign,
      );

  Widget _moduleSplitSegmented(Palette palette) => _segmented<bool>(
        palette,
        values: const [false, true],
        selected: planProvider.moduleSplit,
        labelOf: (v) => v ? '时钟靠左+计划靠右' : '底部横条',
        onChanged: planProvider.setModuleSplit,
      );

  Widget _moduleTimeSegmented(Palette palette) => _segmented<String>(
        palette,
        values: const ['elapsed', 'remaining', 'both'],
        selected: planProvider.moduleTime,
        labelOf: (v) => switch (v) {
          'elapsed' => '已执行',
          'remaining' => '剩余',
          'both' => '都显示',
          _ => v,
        },
        onChanged: planProvider.setModuleTime,
      );

  /// 计划生成帮助:弹窗选择「生成计划」或「生成计划结构清单」
  void _openPlanHelp(BuildContext context, Palette palette) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.card,
        title: Text('计划生成帮助',
            style: TextStyle(color: palette.foreground)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading:
                  Icon(Icons.calendar_month, color: palette.accent),
              title: Text('借助 AI 生成计划',
                  style: TextStyle(color: palette.foreground)),
              subtitle: Text('按计划字段生成 JSON,可粘贴导入',
                  style: TextStyle(color: palette.secondary, fontSize: 12)),
              onTap: () {
                Navigator.of(ctx).pop();
                _showAiPrompt(context, palette);
              },
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.account_tree_outlined,
                  color: palette.accent),
              title: Text('借助 AI 生成计划结构清单',
                  style: TextStyle(color: palette.foreground)),
              subtitle: Text('生成类型›主题›单元›标题四层结构 JSON',
                  style: TextStyle(color: palette.secondary, fontSize: 12)),
              onTap: () {
                Navigator.of(ctx).pop();
                _showAiPromptCandidates(context, palette);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('取消', style: TextStyle(color: palette.secondary)),
          ),
        ],
      ),
    );
  }

  /// 生成「计划结构清单」的规范 AI 提示词并复制到剪贴板
  void _showAiPromptCandidates(BuildContext context, Palette palette) {
    const prompt = '''
你是 Fullscreen Clock 全屏时钟的「计划结构清单」生成助手。请根据用户描述,生成一个候选清单 JSON,只输出 JSON,不要任何解释文字。

【输出格式】
{
  "schemaVersion": "1.0.0",
  "candidates": [
    {
      "type": "计划类型(一级)",
      "topic": "计划主题(二级)",
      "unit": "计划单元(三级)",
      "title": "标题(四级)"
    }
  ]
}

【规则】
- 结构为四层:类型(一级)→ 主题(二级)→ 单元(三级)→ 标题(四级)。
- 每条候选必须含 type/topic/unit/title 四个字段,均不能为空。
- 相同层级结构(同 type/topic/unit)可以有多条 title。
- 若用户给出口语化清单,按层级归类生成;不要臆造用户未提到的层级。

【用户描述】
''';
    Clipboard.setData(const ClipboardData(text: prompt));
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.card,
        title: Text('AI 生成计划结构清单',
            style: TextStyle(color: palette.foreground, fontSize: 17)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle,
                      color: const Color(0xFF1FAF58), size: 18),
                  const SizedBox(width: 6),
                  Text('提示词已复制到剪贴板',
                      style:
                          TextStyle(color: palette.foreground, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '发给任意 AI 生成候选清单 JSON,然后在 设置→计划→候选清单 →右上角 ⋮ →「导入」或「粘贴导入」中导入。',
                style: TextStyle(color: palette.secondary, fontSize: 13),
              ),
              const SizedBox(height: 10),
              SelectableText(
                prompt,
                style: TextStyle(
                    color: palette.foreground,
                    fontSize: 12,
                    fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('关闭', style: TextStyle(color: palette.accent)),
          ),
        ],
      ),
    );
  }

  /// 生成规范的 AI 提示词并复制到剪贴板
  void _showAiPrompt(BuildContext context, Palette palette) {
    const prompt = '''
你是 Fullscreen Clock 全屏时钟的计划生成助手。请根据用户描述的计划,生成一个符合以下规范的 JSON。只输出 JSON,不要任何解释文字。

【输出格式】
{
  "schemaVersion": "1.0.0",
  "plans": [
    {
      "id": "plan-001",
      "type": "计划类型(一级,如 学习)",
      "topic": "计划主题(二级,如 行测)",
      "unit": "计划单元(三级,如 判断推理)",
      "title": "计划标题(必填)",
      "startDate": "2026-08-20T10:00:00",
      "durationMinutes": 60,
      "notes": "备注,可省略",
      "color": 4283216694,
      "iconName": "schedule",
      "tags": ["标签"],
      "progressType": "automatic",
      "remindersMinBefore": [0, 10],
      "repeat": {
        "frequency": "none",
        "interval": 1,
        "daysOfWeek": [],
        "daysOfMonth": [],
        "endType": "never",
        "untilDate": null,
        "repeatCount": null
      }
    }
  ]
}

【字段规则】
- id: 计划唯一标识,必填,任意非空且不重复的字符串(如 plan-001)。
- type: 计划类型(一级),可省略。
- topic: 计划主题(二级),可省略。
- unit: 计划单元(三级),可省略。
- title: 计划标题,必填,简洁明确。
- startDate: 开始时间,**写本地时间,不要带时区后缀 Z 或 +08:00**(如 2026-08-20T10:00:00)。用户没给具体年份时默认当年。
- **多条计划的时间段不能重叠**(一条计划的开始到结束区间内不允许出现另一条计划)。
- durationMinutes: 时长(分钟),5~300 之间的正整数。
- notes: 备注内容(可选)。
- color: 颜色,用 0xFFRRGGBB 对应的十进制整数(可省略,默认 4283216694)。
- iconName: 图标,从 schedule/book/fitness/sleep/work/school/coffee/home/music/flag/star/target/restaurant/directions_run 中选一个。
- tags: 标签数组(可选)。
- progressType: automatic(按时间自动)/ manual(开始后手动)/ none(不设置进度),默认 automatic。
- remindersMinBefore: 提醒分钟数组,建议 [0, 10](准时+提前10分钟),不需要提醒用 []。
- repeat.frequency: none(不重复)/ daily(每天)/ weekly(每周)/ workdays(工作日)/ monthly(每月)。
  - weekly 时 daysOfWeek 用 [1..7](1=周一)。
  - monthly 时 daysOfMonth 用 [1,15] 等,负数表示月末倒数。
  - endType: never/until/count,until 时 untilDate 给日期,count 时 repeatCount 给次数。

【用户描述的计划】
请把用户下面这段描述转换为 JSON(可包含多条计划;若是表格/列表,按行转换):
''';
    Clipboard.setData(const ClipboardData(text: prompt));
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.card,
        title: Text('AI 生成计划提示词',
            style: TextStyle(color: palette.foreground, fontSize: 17)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle,
                      color: const Color(0xFF1FAF58), size: 18),
                  const SizedBox(width: 6),
                  Text('提示词已复制到剪贴板',
                      style: TextStyle(color: palette.foreground, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '发给任意 AI,粘贴你的口语化计划描述,AI 会返回规范 JSON。'
                '然后在「计划列表 → 粘贴计划」中导入。',
                style: TextStyle(color: palette.secondary, fontSize: 13),
              ),
              const SizedBox(height: 10),
              Text(
                prompt,
                style: TextStyle(
                    color: palette.foreground,
                    fontSize: 12,
                    fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('关闭', style: TextStyle(color: palette.accent)),
          ),
        ],
      ),
    );
  }

  void _openNotificationSettings(BuildContext context, Palette palette) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.card,
      builder: (ctx) => PlanNotificationSettingsSheet(
        planProvider: planProvider,
        palette: palette,
      ),
    );
  }

  Future<void> _openUrl(String url, BuildContext context) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开浏览器')),
      );
    }
  }

  void _confirmReset(BuildContext context, Palette palette) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: palette.card,
        title: Text('恢复默认设置',
            style: TextStyle(color: palette.foreground)),
        content: Text('确定要将所有设置恢复为默认值吗?',
            style: TextStyle(color: palette.foreground)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('取消', style: TextStyle(color: palette.secondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              provider.reset();
            },
            child: Text('确定', style: TextStyle(color: palette.accent)),
          ),
        ],
      ),
    );
  }

  // ---- 字体颜色区 ----

  Widget _fontColorSection(ClockSettings settings, Palette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _segmented<FontColorMode>(
          palette,
          values: FontColorMode.values,
          selected: settings.fontColorMode,
          labelOf: (m) => m == FontColorMode.follow ? '跟随主题' : '自定义',
          onChanged: provider.setFontColorMode,
        ),
        if (settings.fontColorMode == FontColorMode.custom) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              _HexField(
                label: '白天字体色',
                initial: settings.fontColorLight ?? const Color(0xFF1B1B1F),
                onChanged: provider.setFontColorLight,
              ),
              const SizedBox(width: 10),
              _HexField(
                label: '黑夜字体色',
                initial: settings.fontColorDark ?? const Color(0xFFFFFFFF),
                onChanged: provider.setFontColorDark,
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ---- 背景颜色区 ----

  Widget _bgColorSection(ClockSettings settings, Palette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _segmented<BackgroundColorMode>(
          palette,
          values: BackgroundColorMode.values,
          selected: settings.bgColorMode,
          labelOf: (m) => m == BackgroundColorMode.follow ? '跟随主题' : '自定义',
          onChanged: provider.setBgColorMode,
        ),
        if (settings.bgColorMode == BackgroundColorMode.custom) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              _HexField(
                label: '白天背景色',
                initial: settings.bgColorLight ?? const Color(0xFFFFFFFF),
                onChanged: provider.setBgColorLight,
              ),
              const SizedBox(width: 10),
              _HexField(
                label: '黑夜背景色',
                initial: settings.bgColorDark ?? const Color(0xFF000000),
                onChanged: provider.setBgColorDark,
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ---- 配色方案区 ----

  Widget _paletteSection(ClockSettings settings, BuildContext context) {
    final dark = settings.theme == ClockTheme.dark ||
        (settings.theme == ClockTheme.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    final customIndex = settings.paletteIndex - ClockSettings.presetPaletteCount;
    final showCustomEditor = settings.paletteIndex >=
            ClockSettings.presetPaletteCount &&
        customIndex >= 0 &&
        customIndex < settings.customPalettes.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 内置预设色卡
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (var i = 0; i < kPalettePresets.length; i++)
              _swatch(
                name: kPalettePresets[i].name,
                bg: _presetBg(i, dark),
                dot: kPalettePresets[i].dark.accent,
                selected: settings.paletteIndex == i,
                onTap: () => provider.setPaletteIndex(i),
              ),
          ],
        ),
        const SizedBox(height: 12),
        // 自定义方案色卡 + 添加
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (var i = 0; i < settings.customPalettes.length; i++)
              _swatch(
                name: '自定义${i + 1}',
                bg: settings.customPalettes[i].bg,
                dot: settings.customPalettes[i].accent,
                selected: settings.paletteIndex ==
                    ClockSettings.presetPaletteCount + i,
                onTap: () => provider
                    .setPaletteIndex(ClockSettings.presetPaletteCount + i),
              ),
            if (settings.customPalettes.length < 10)
              _addSwatch(() => _addCustomPaletteDialog(settings, context)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '自定义方案最多 10 个,可输入十六进制色码(如 FF0000)',
          style: TextStyle(
            color:
                dark ? const Color(0xFF80808A) : const Color(0xFF8A8A93),
            fontSize: 12,
          ),
        ),
        // 选中的自定义方案内联编辑
        if (showCustomEditor) _customEditRow(settings, customIndex),
      ],
    );
  }

  Color _presetBg(int i, bool dark) {
    final preset = kPalettePresets[i];
    return dark ? preset.dark.background : preset.light.background;
  }

  /// 选中自定义方案时的编辑行(实时更新 + 删除)
  Widget _customEditRow(ClockSettings settings, int index) {
    final c = settings.customPalettes[index];
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          _HexField(
            label: '背景',
            initial: c.bg,
            onChanged: (v) => provider.updateCustomPalette(
                index, CustomPalette(bg: v, fg: c.fg, accent: c.accent)),
          ),
          const SizedBox(width: 10),
          _HexField(
            label: '文字',
            initial: c.fg,
            onChanged: (v) => provider.updateCustomPalette(
                index, CustomPalette(bg: c.bg, fg: v, accent: c.accent)),
          ),
          const SizedBox(width: 10),
          _HexField(
            label: '强调',
            initial: c.accent,
            onChanged: (v) => provider.updateCustomPalette(
                index, CustomPalette(bg: c.bg, fg: c.fg, accent: v)),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: '删除该配色',
            onPressed: () => provider.removeCustomPalette(index),
            icon: Icon(Icons.delete_outline, color: c.accent, size: 20),
          ),
        ],
      ),
    );
  }

  Future<void> _addCustomPaletteDialog(
      ClockSettings settings, BuildContext context) async {
    const def = CustomPalette(
      bg: Color(0xFF1A1A1A),
      fg: Color(0xFFFFFFFF),
      accent: Color(0xFFE53935),
    );
    final result = await showDialog<CustomPalette>(
      context: context,
      builder: (dialogContext) => _AddPaletteDialog(initial: def),
    );
    if (result != null) provider.addCustomPalette(result);
  }

  Widget _swatch({
    required String name,
    required Color bg,
    required Color dot,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: name,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 50,
          height: 50,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? dot : dot.withValues(alpha: 0.4),
              width: selected ? 3 : 1,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              ),
              Center(
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addSwatch(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF8A8A93)),
        ),
        child: const Icon(Icons.add, color: Color(0xFF8A8A93)),
      ),
    );
  }

  // ---- 字体区 ----

  Widget _fontSection(ClockSettings settings, Palette palette) {
    final hasCustom = settings.customFontFamily != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 字体选择:用 Wrap+ChoiceChip 支持换行,避免竖屏一行过挤
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final v in FontStyleOption.values)
              ChoiceChip(
                label: Text(_fontLabel(v)),
                selected: settings.fontStyle == v,
                onSelected: (_) => provider.setFontStyle(v),
                showCheckmark: false,
                labelStyle: TextStyle(
                  fontSize: 13,
                  color: settings.fontStyle == v
                      ? palette.background
                      : palette.foreground,
                ),
                selectedColor: palette.foreground,
                backgroundColor: palette.card,
                side: BorderSide(color: palette.cardBorder),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: palette.accent,
            side: BorderSide(color: palette.accent),
            visualDensity: VisualDensity.compact,
          ),
          onPressed: () => _importFont(),
          icon: const Icon(Icons.font_download_outlined, size: 18),
          label: Text(hasCustom ? '重新导入字体' : '导入自定义字体(.ttf/.otf)'),
        ),
        if (hasCustom) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.check_circle, color: palette.accent, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '已导入: ${settings.customFontFamily}',
                  style: TextStyle(color: palette.secondary, fontSize: 12),
                ),
              ),
              TextButton(
                onPressed: () => provider.setCustomFontFamily(null),
                child: Text('移除', style: TextStyle(color: palette.accent, fontSize: 12)),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _importFont() async {
    final family = await FontService.pickAndInstallFont();
    if (family != null) {
      provider.setCustomFontFamily(family);
      provider.setFontStyle(FontStyleOption.custom);
    }
  }

  // ---- 布局辅助 ----

  Widget _groupTitle(Palette palette, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        text,
        style: TextStyle(
          color: palette.secondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _card(Palette palette, {required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.cardBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: child,
    );
  }

  Widget _divider(Palette palette) =>
      Divider(height: 1, thickness: 1, color: palette.cardBorder);

  Widget _optionRow(Palette palette, {required String title, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _label(palette)),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: child),
        ],
      ),
    );
  }

  Widget _segmented<T>(
    Palette palette, {
    required List<T> values,
    required T selected,
    required String Function(T) labelOf,
    required ValueChanged<T> onChanged,
    bool enabled = true,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: SegmentedButton<T>(
        segments: [
          for (final v in values)
            ButtonSegment(value: v, label: Text(labelOf(v))),
        ],
        selected: {selected},
        onSelectionChanged: enabled ? (s) => onChanged(s.first) : null,
        showSelectedIcon: false,
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? palette.background
                : palette.foreground,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? palette.foreground
                : palette.card,
          ),
          side: WidgetStatePropertyAll(BorderSide(color: palette.cardBorder)),
          visualDensity: VisualDensity.compact,
          textStyle: WidgetStatePropertyAll(const TextStyle(fontSize: 13)),
        ),
      ),
    );
  }

  Widget _switchTile(
    Palette palette, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: _label(palette)),
      subtitle: Text(subtitle, style: TextStyle(color: palette.secondary, fontSize: 12)),
      value: value,
      activeThumbColor: palette.accent,
      activeTrackColor: palette.accent.withValues(alpha: 0.35),
      onChanged: onChanged,
    );
  }

  TextStyle _label(Palette palette) =>
      TextStyle(color: palette.foreground, fontSize: 16);

  static String _modeLabel(ClockMode m) => switch (m) {
        ClockMode.standard => '标准',
        ClockMode.analog => '圆盘',
      };

  static String _themeLabel(ClockTheme t) => switch (t) {
        ClockTheme.light => '白天',
        ClockTheme.dark => '黑夜',
        ClockTheme.system => '跟随系统',
      };

  static String _fontLabel(FontStyleOption f) => switch (f) {
        FontStyleOption.normal => '默认',
        FontStyleOption.mono => '等宽',
        FontStyleOption.serif => '衬线',
        FontStyleOption.harmonyos => 'HarmonyOS Sans',
        FontStyleOption.misans => 'MiSans',
        FontStyleOption.custom => '自定义',
      };

  static String _analogLabel(AnalogClockStyle s) => switch (s) {
        AnalogClockStyle.minimal => '极简',
        AnalogClockStyle.classic => '经典',
        AnalogClockStyle.roman => '罗马',
        AnalogClockStyle.dots => '圆点',
      };

  static Color? _parseHex(String text) {
    var t = text.trim().replaceAll('#', '');
    if (t.length == 6) {
      return Color(int.tryParse('FF$t', radix: 16) ?? 0);
    }
    if (t.length == 8) {
      return Color(int.tryParse(t, radix: 16) ?? 0);
    }
    return null;
  }
}

/// 统一滑杆行:标题 + Slider + 手动输入倍率,拖动用本地状态避免频繁重建
class _ScaleSliderRow extends StatefulWidget {
  const _ScaleSliderRow({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.showPercent,
    required this.palette,
    required this.onChanged,
  });

  final String title;
  final double value;
  final double min;
  final double max;
  final bool showPercent;
  final Palette palette;
  final ValueChanged<double> onChanged;

  @override
  State<_ScaleSliderRow> createState() => _ScaleSliderRowState();
}

class _ScaleSliderRowState extends State<_ScaleSliderRow> {
  double? _drag;

  double get _cur => _drag ?? widget.value;

  String get _displayText => widget.showPercent
      ? '${(_cur * 100).round()}%'
      : '${_cur.round()}';

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(widget.title, style: TextStyle(color: palette.foreground, fontSize: 16))),
              SizedBox(
                width: 150,
                child: Slider(
                  value: _cur.clamp(widget.min, widget.max),
                  min: widget.min,
                  max: widget.max,
                  activeColor: palette.accent,
                  inactiveColor: palette.secondary,
                  label: _displayText,
                  onChanged: (v) => setState(() => _drag = v),
                  onChangeEnd: (v) {
                    widget.onChanged(v);
                    setState(() => _drag = null);
                  },
                ),
              ),
              _ScaleField(
                value: _cur,
                min: widget.min,
                max: widget.max,
                palette: palette,
                onChanged: (v) {
                  widget.onChanged(v);
                  setState(() => _drag = v);
                },
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              _displayText,
              style: TextStyle(color: palette.secondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// 手动输入倍率的输入框
class _ScaleField extends StatefulWidget {
  const _ScaleField({
    required this.value,
    required this.min,
    required this.max,
    required this.palette,
    required this.onChanged,
  });

  final double value;
  final double min;
  final double max;
  final Palette palette;
  final ValueChanged<double> onChanged;

  @override
  State<_ScaleField> createState() => _ScaleFieldState();
}

class _ScaleFieldState extends State<_ScaleField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _fmt(widget.value));
  }

  @override
  void didUpdateWidget(_ScaleField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _controller.text = _fmt(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _fmt(double v) => v == v.roundToDouble()
      ? '${v.toInt()}'
      : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      child: TextField(
        controller: _controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        style: TextStyle(color: widget.palette.foreground, fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: widget.palette.background,
          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: widget.palette.cardBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: widget.palette.cardBorder),
          ),
        ),
        onSubmitted: (text) {
          final v = double.tryParse(text.trim());
          if (v != null) {
            widget.onChanged(v.clamp(widget.min, widget.max));
          }
        },
      ),
    );
  }
}

/// 新增自定义配色的对话框
class _AddPaletteDialog extends StatefulWidget {
  const _AddPaletteDialog({required this.initial});

  final CustomPalette initial;

  @override
  State<_AddPaletteDialog> createState() => _AddPaletteDialogState();
}

class _AddPaletteDialogState extends State<_AddPaletteDialog> {
  late CustomPalette _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initial;
  }

  void _set({Color? bg, Color? fg, Color? accent}) {
    setState(() {
      _value = CustomPalette(
        bg: bg ?? _value.bg,
        fg: fg ?? _value.fg,
        accent: accent ?? _value.accent,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新建自定义配色'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _HexField(label: '背景', initial: _value.bg, onChanged: (v) => _set(bg: v)),
              const SizedBox(width: 10),
              _HexField(label: '文字', initial: _value.fg, onChanged: (v) => _set(fg: v)),
              const SizedBox(width: 10),
              _HexField(label: '强调', initial: _value.accent, onChanged: (v) => _set(accent: v)),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '输入 6 位十六进制色码,如 FF0000',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_value),
          child: const Text('确定'),
        ),
      ],
    );
  }
}

/// 十六进制颜色输入框(输入 6 位色码实时生效)
class _HexField extends StatefulWidget {
  const _HexField({
    required this.label,
    required this.initial,
    required this.onChanged,
  });

  final String label;
  final Color initial;
  final ValueChanged<Color> onChanged;

  @override
  State<_HexField> createState() => _HexFieldState();
}

class _HexFieldState extends State<_HexField> {
  late final TextEditingController _controller;

  static String _toHex(Color c) =>
      c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _toHex(widget.initial));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.text,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'RRGGBB',
              hintStyle: const TextStyle(fontSize: 12),
              filled: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (text) {
              final c = SettingsScreen._parseHex(text);
              if (c != null) widget.onChanged(c);
            },
          ),
        ],
      ),
    );
  }
}

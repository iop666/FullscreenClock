import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/plan.dart';
import '../models/plan_history.dart';
import '../models/plan_repeat.dart';
import '../providers/plan_provider.dart';
import '../services/plan_export_service.dart';
import '../theme/app_theme.dart';
import '../utils/plan_json.dart';
import '../utils/plan_time.dart';
import 'plan_all_screen.dart';
import 'plan_edit_screen.dart';

/// 计划列表页:本日/本周/本月范围、时间正/倒序、详情展开、提前/延后/复制/删除、导入导出粘贴
class PlanListScreen extends StatefulWidget {
  const PlanListScreen({
    super.key,
    required this.planProvider,
    required this.palette,
  });

  final PlanProvider planProvider;
  final Palette palette;

  @override
  State<PlanListScreen> createState() => _PlanListScreenState();
}

enum _PlanRange { today, tomorrow, week, month }

class _PlanListScreenState extends State<PlanListScreen> {
  _PlanRange _range = _PlanRange.today;
  final DateTime _day = DateTime.now();
  bool _desc = false;
  String? _expandedKey;

  PlanProvider get planProvider => widget.planProvider;
  Palette get palette => widget.palette;

  List<PlanOccurrence> _occurrences() {
    final plans = planProvider.plans;
    return switch (_range) {
      _PlanRange.today => occurrencesOnDay(plans, _day),
      _PlanRange.tomorrow =>
        occurrencesOnDay(plans, _day.add(const Duration(days: 1))),
      _PlanRange.week => () {
          final monday = _startOfWeek(_day);
          return occurrencesInRange(
              plans, monday, monday.add(const Duration(days: 6)));
        }(),
      _PlanRange.month => () {
          final first = DateTime(_day.year, _day.month, 1);
          final last = DateTime(_day.year, _day.month + 1, 0);
          return occurrencesInRange(plans, first, last);
        }(),
    };
  }

  DateTime _startOfWeek(DateTime d) =>
      startOfDay(d).subtract(Duration(days: d.weekday - 1));

  /// 排序键:已完成计划按实际完成时间,其余按预定开始时间
  DateTime _sortKey(PlanOccurrence occ) {
    final hist = planProvider.history
        .where((h) => h.planId == occ.plan.id && h.dateKey == occ.dateKey)
        .toList();
    if (hist.isNotEmpty && hist.first.finalStatus == PlanStatus.completed) {
      final end = hist.first.actualEnd;
      if (end != null) return end;
    }
    return occ.scheduledStart;
  }

  String _rangeLabel() => switch (_range) {
        _PlanRange.today => '今天',
        _PlanRange.tomorrow => '明天',
        _PlanRange.week => '本周 · 周一到周日',
        _PlanRange.month => '${_day.year}年${_day.month}月',
      };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: planProvider,
      builder: (context, _) {
        final occs = [..._occurrences()]..sort((a, b) {
            final ka = _sortKey(a);
            final kb = _sortKey(b);
            return _desc ? kb.compareTo(ka) : ka.compareTo(kb);
          });
        return Scaffold(
          backgroundColor: palette.background,
          appBar: AppBar(
            backgroundColor: palette.background,
            foregroundColor: palette.foreground,
            elevation: 0,
            title: const Text('计划列表'),
            actions: [
              PopupMenuButton<String>(
                color: palette.card,
                onSelected: _onMenu,
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'all',
                    child: Text('查看全部',
                        style: TextStyle(color: palette.foreground)),
                  ),
                  PopupMenuItem(
                    value: 'undone',
                    child: Text('查看所有未完成',
                        style: TextStyle(color: palette.foreground)),
                  ),
                  PopupMenuItem(
                    value: 'sort',
                    child: Text(_desc ? '时间正序' : '时间倒序',
                        style: TextStyle(color: palette.foreground)),
                  ),
                  PopupMenuItem(
                    value: 'export',
                    child: Text('导出计划',
                        style: TextStyle(color: palette.foreground)),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _segmented(
                    values: _PlanRange.values,
                    selected: _range,
                    labelOf: (r) => switch (r) {
                      _PlanRange.today => '今日',
                      _PlanRange.tomorrow => '明日',
                      _PlanRange.week => '本周',
                      _PlanRange.month => '本月',
                    },
                    onChanged: (r) => setState(() => _range = r),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
                child: Row(
                  children: [
                    Text(_rangeLabel(),
                        style: TextStyle(color: palette.secondary, fontSize: 12)),
                    const Spacer(),
                    Text(_desc ? '时间倒序' : '时间正序',
                        style: TextStyle(color: palette.secondary, fontSize: 12)),
                  ],
                ),
              ),
              Expanded(
                child: occs.isEmpty
                    ? Center(
                        child: Text(
                          '该范围暂无计划\n点击右下角 + 添加',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: palette.secondary, fontSize: 15),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                        itemCount: occs.length,
                        itemBuilder: (context, i) {
                          final occ = occs[i];
                          final key = '${occ.plan.id}|${occ.dateKey}';
                          final hist = planProvider.history
                              .where((h) =>
                                  h.planId == occ.plan.id &&
                                  h.dateKey == occ.dateKey)
                              .toList();
                          return _OccurrenceTile(
                            occ: occ,
                            rt: planProvider.runtimeFor(occ),
                            hist: hist.isEmpty ? null : hist.first,
                            palette: palette,
                            now: DateTime.now(),
                            expanded: _expandedKey == key,
                            onToggle: () => setState(() => _expandedKey =
                                _expandedKey == key ? null : key),
                            onEdit: () => _openEditor(context, plan: occ.plan),
                            onAdvance: () => _moveDialog(context, occ.plan, advance: true),
                            onDelay: () => _moveDialog(context, occ.plan, advance: false),
                            onDelete: () => _delete(context, occ.plan),
                            canCancelRunning: _runningNow(planProvider.runtimeFor(occ)),
                            onCancelRunning: () => planProvider.cancelRunning(
                                occ.plan.id, DateTime.now()),
                          );
                        },
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: palette.accent,
            foregroundColor: palette.background,
            onPressed: () => _fabMenu(context),
            tooltip: '添加计划',
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  // ---- 菜单 ----

  void _onMenu(String v) {
    switch (v) {
      case 'all':
        _openAll(false);
      case 'undone':
        _openAll(true);
      case 'sort':
        setState(() => _desc = !_desc);
      case 'export':
        _exportPlans(context);
    }
  }

  void _openAll(bool undoneOnly) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PlanAllScreen(
        planProvider: planProvider,
        palette: palette,
        undoneOnly: undoneOnly,
      ),
    ));
  }

  bool _runningNow(PlanRuntime? rt) {
    if (rt == null) return false;
    return rt.status == PlanStatus.active ||
        rt.status == PlanStatus.paused ||
        rt.status == PlanStatus.overdue;
  }

  void _fabMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.card,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.add_circle_outline, color: palette.accent),
              title: Text('新建计划', style: TextStyle(color: palette.foreground)),
              onTap: () {
                Navigator.of(ctx).pop();
                _openEditor(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.upload_file, color: palette.accent),
              title: Text('导入计划', style: TextStyle(color: palette.foreground)),
              onTap: () {
                Navigator.of(ctx).pop();
                _importPlans(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.content_paste, color: palette.accent),
              title: Text('粘贴计划', style: TextStyle(color: palette.foreground)),
              onTap: () {
                Navigator.of(ctx).pop();
                _pastePlans(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openEditor(BuildContext context, {Plan? plan}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlanEditScreen(
          planProvider: planProvider,
          palette: palette,
          plan: plan,
        ),
      ),
    );
  }

  // ---- 提前/延后 ----

  Future<void> _moveDialog(
      BuildContext context, Plan plan, {required bool advance}) async {
    const options = [15, 30, 60, 120];
    final minutes = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.card,
        title: Text(advance ? '计划提前(分钟)' : '计划延后(分钟)',
            style: TextStyle(color: palette.foreground, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in options)
                  ChoiceChip(
                    label: Text('$m'),
                    selected: false,
                    onSelected: (_) => Navigator.of(ctx).pop(m),
                    selectedColor: palette.foreground,
                    backgroundColor: palette.background,
                    labelStyle: TextStyle(color: palette.foreground),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              keyboardType: TextInputType.number,
              style: TextStyle(color: palette.foreground, fontSize: 15),
              decoration: InputDecoration(
                labelText: '自定义分钟',
                isDense: true,
                filled: true,
                fillColor: palette.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onSubmitted: (t) {
                final n = int.tryParse(t);
                if (n != null && n > 0) Navigator.of(ctx).pop(n);
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
    if (minutes != null && minutes > 0) {
      final err = planProvider.movePlan(
        plan.id,
        Duration(minutes: advance ? -minutes : minutes),
      );
      if (err != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('无法${advance ? '提前' : '延后'}:$err'),
        ));
      }
    }
  }

  // ---- 删除 ----

  void _delete(BuildContext context, Plan plan) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.card,
        title: Text('删除计划',
            style: TextStyle(color: palette.foreground)),
        content: Text(
          '确定删除「${plan.title}」吗?',
          style: TextStyle(color: palette.foreground),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('取消', style: TextStyle(color: palette.secondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              planProvider.deletePlan(plan.id);
            },
            child: const Text('删除', style: TextStyle(color: Color(0xFFE53935))),
          ),
        ],
      ),
    );
  }

  // ---- 导出/导入/粘贴 ----

  Future<void> _exportPlans(BuildContext context) async {
    final palette = this.palette;
    if (PlanExportService.hasSensitiveContent(planProvider)) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: palette.card,
          title: Text('导出隐私提示',
              style: TextStyle(color: palette.foreground)),
          content: Text('导出内容包含备注或标签,可能含敏感信息。确定导出吗?',
              style: TextStyle(color: palette.foreground)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text('取消',
                  style: TextStyle(color: palette.foreground)),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text('确定导出',
                  style: TextStyle(color: palette.accent)),
            ),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
    }
    final path = await PlanExportService.exportToFile(planProvider);
    if (path != null && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('已导出: $path')));
    }
  }

  Future<void> _importPlans(BuildContext context) async {
    final picked = await PlanExportService.pickJsonFile();
    if (picked == null || !context.mounted) return;
    await _importFromText(context, picked.content);
  }

  Future<void> _pastePlans(BuildContext context) async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text;
    if (text == null || text.trim().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('剪贴板没有可粘贴的内容')));
      }
      return;
    }
    if (!context.mounted) return;
    await _importFromText(context, text);
  }

  /// 统一导入流程:校验 → 重叠拦截 → 确认 → 导入(共存)
  Future<void> _importFromText(BuildContext context, String content) async {
    final root = decodeExportJson(content);
    if (root == null) {
      _showDialog('导入失败', '剪贴板/文件不是有效的计划 JSON');
      return;
    }
    final report = validateImport(root);
    if (report.hasErrors) {
      _showDialog('导入失败', report.errors.join('\n'));
      return;
    }
    final parsed = parseImportedPlans(root);
    // 强拦截:导入计划之间或与现有计划存在重叠 → 阻止导入
    if (_hasInternalOverlap(parsed.plans) ||
        _importsOverlapExisting(parsed.plans)) {
      _showDialog(
          '无法导入',
          '导入的计划与现有计划(或导入计划之间)存在时间重叠。'
          '请调整计划时间后重试,不允许同时段存在多个计划。');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: palette.card,
        title: Text('确认导入',
            style: TextStyle(color: palette.foreground)),
        content: Text(
          '将导入 ${parsed.plans.length} 个计划,与现有 ${planProvider.plans.length} 个计划共存。继续?',
          style: TextStyle(color: palette.foreground),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('取消', style: TextStyle(color: palette.secondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('导入', style: TextStyle(color: palette.accent)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final result =
        PlanExportService.importContent(planProvider, content);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result.hasErrors
          ? '导入失败:${result.errors.join(',')}'
          : '导入完成${result.warnings.isEmpty ? '' : ',${result.warnings.length} 条已跳过'}'),
    ));
  }

  /// 导入的计划之间在未来 60 天内是否有时间重叠
  bool _hasInternalOverlap(List<Plan> imported) {
    final from = DateTime.now();
    final to = from.add(const Duration(days: 60));
    for (var i = 0; i < imported.length; i++) {
      for (var j = i + 1; j < imported.length; j++) {
        if (_plansOverlap(imported[i], imported[j], from, to)) return true;
      }
    }
    return false;
  }

  /// 导入的计划与现有计划在未来 60 天内是否有时间重叠
  bool _importsOverlapExisting(List<Plan> imported) {
    final existing = planProvider.plans;
    final from = DateTime.now();
    final to = from.add(const Duration(days: 60));
    for (final a in imported) {
      for (final b in existing) {
        if (_plansOverlap(a, b, from, to)) return true;
      }
    }
    return false;
  }

  bool _plansOverlap(Plan a, Plan b, DateTime from, DateTime to) {
    var d = startOfDay(from);
    final last = startOfDay(to);
    while (!d.isAfter(last)) {
      final oa = occurrenceOn(a, d);
      final ob = occurrenceOn(b, d);
      if (oa != null &&
          ob != null &&
          oa.scheduledEnd.isAfter(ob.scheduledStart) &&
          ob.scheduledEnd.isAfter(oa.scheduledStart)) {
        return true;
      }
      d = d.add(const Duration(days: 1));
    }
    return false;
  }

  void _showDialog(String title, String content) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.card,
        title: Text(title, style: TextStyle(color: palette.foreground)),
        content: SingleChildScrollView(
          child: Text(content, style: TextStyle(color: palette.foreground, fontSize: 14)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('知道了', style: TextStyle(color: palette.accent)),
          ),
        ],
      ),
    );
  }

  Widget _segmented<T>({
    required List<T> values,
    required T selected,
    required String Function(T) labelOf,
    required ValueChanged<T> onChanged,
  }) {
    return SegmentedButton<T>(
      segments: [for (final v in values) ButtonSegment(value: v, label: Text(labelOf(v)))],
      selected: {selected},
      onSelectionChanged: (s) => onChanged(s.first),
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
    );
  }
}

/// 计划实例列表项:可展开详情,已完成变灰、进行中高亮
class _OccurrenceTile extends StatelessWidget {
  const _OccurrenceTile({
    required this.occ,
    required this.rt,
    required this.hist,
    required this.palette,
    required this.now,
    required this.expanded,
    required this.onToggle,
    required this.onEdit,
    required this.onAdvance,
    required this.onDelay,
    required this.onDelete,
    required this.canCancelRunning,
    required this.onCancelRunning,
  });

  final PlanOccurrence occ;
  final PlanRuntime? rt;
  final PlanHistoryRecord? hist;
  final Palette palette;
  final DateTime now;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onAdvance;
  final VoidCallback onDelay;
  final VoidCallback onDelete;
  final bool canCancelRunning;
  final VoidCallback onCancelRunning;

  PlanStatus get _status {
    if (rt != null) return rt!.status;
    if (hist != null) return hist!.finalStatus;
    return PlanStatus.unstarted;
  }

  bool get _done => _status == PlanStatus.completed;
  bool get _active => _status == PlanStatus.active;

  @override
  Widget build(BuildContext context) {
    final plan = occ.plan;
    final doneColor = palette.secondary.withValues(alpha: 0.6);
    final titleColor = _done ? doneColor : palette.foreground;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _active ? palette.accent : palette.cardBorder,
          width: _active ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _done
                          ? palette.secondary.withValues(alpha: 0.4)
                          : Color(plan.color),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(plan.iconData, size: 16,
                                color: _done ? doneColor : Color(plan.color)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                plan.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: titleColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            _StatusBadge(palette: palette, status: _status),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _subtitle(),
                          style: TextStyle(
                            color: _done ? doneColor : palette.secondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    color: palette.card,
                    onSelected: (v) => switch (v) {
                      'edit' => onEdit(),
                      'advance' => onAdvance(),
                      'delay' => onDelay(),
                      'cancel' => onCancelRunning(),
                      'del' => onDelete(),
                      _ => null,
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                          value: 'edit',
                          child: Text('修改计划',
                              style: TextStyle(color: palette.foreground))),
                      PopupMenuItem(
                          value: 'advance',
                          child: Text('计划提前',
                              style: TextStyle(color: palette.foreground))),
                      PopupMenuItem(
                          value: 'delay',
                          child: Text('计划延后',
                              style: TextStyle(color: palette.foreground))),
                      if (canCancelRunning)
                        PopupMenuItem(
                          value: 'cancel',
                          child: Text('取消运行状态',
                              style: TextStyle(color: palette.foreground))),
                      PopupMenuItem(
                          value: 'del',
                          child: Text('删除',
                              style: TextStyle(color: Color(0xFFE53935)))),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (expanded) _detail(),
        ],
      ),
    );
  }

  String _subtitle() {
    final plan = occ.plan;
    final date = '${occ.day.month.toString().padLeft(2, '0')}-${occ.day.day.toString().padLeft(2, '0')}';
    return '$date ${_hhmm(occ.scheduledStart)} - ${_hhmm(occ.scheduledEnd)} · ${plan.duration.inMinutes} 分钟';
  }

  Widget _detail() {
    final plan = occ.plan;
    final items = <(String, String)>[
      ('开始时间', _fmtDateTime(occ.scheduledStart)),
      ('设置时长', '${plan.duration.inMinutes} 分钟'),
      ('重复模式', _repeatLabel(plan.repeat)),
    ];
    if (plan.notes.isNotEmpty) items.add(('内容', plan.notes));

    // 状态相关
    switch (_status) {
      case PlanStatus.unstarted:
        final cd = occ.scheduledStart.difference(now);
        items.add(('距离开始', _fmtDuration(cd)));
        break;
      case PlanStatus.active:
      case PlanStatus.paused:
        final ra = rt;
        if (ra != null) {
          final end = effectiveEnd(occ, ra, now);
          items.add(('剩余时间', _fmtDuration(end.difference(now))));
          items.add(('实际开始', _fmtDateTime(ra.startedAt)));
        }
        break;
      case PlanStatus.overdue:
        final ro = rt;
        if (ro != null) {
          final end = effectiveEnd(occ, ro, now);
          items.add(('超时', _fmtDuration(now.difference(end))));
          items.add(('实际开始', _fmtDateTime(ro.startedAt)));
        }
        break;
      case PlanStatus.completed:
        final aStart = hist?.actualStart ?? rt?.startedAt;
        final aEnd = hist?.actualEnd ?? rt?.completedAt ?? rt?.startedAt;
        items.add(('实际开始', _fmtDateTime(aStart)));
        items.add(('实际结束', _fmtDateTime(aEnd)));
        if (aStart != null && aEnd != null) {
          final dur = aEnd.difference(aStart) -
              (rt?.totalPausedDuration ?? Duration.zero);
          items.add(
              ('实际持续', _fmtDuration(dur.isNegative ? Duration.zero : dur)));
        }
        items.add(('状态', '已完成'));
        break;
      case PlanStatus.skipped:
        items.add(('状态', '已跳过'));
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.cardBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (label, value) in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 76,
                    child: Text(label,
                        style: TextStyle(color: palette.secondary, fontSize: 12)),
                  ),
                  Expanded(
                    child: Text(value,
                        style: TextStyle(color: palette.foreground, fontSize: 13)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _repeatLabel(RepeatRule r) {
    switch (r.frequency) {
      case PlanRepeatFrequency.none:
        return '不重复';
      case PlanRepeatFrequency.daily:
        return '每天';
      case PlanRepeatFrequency.weekly:
        return r.daysOfWeek.map((w) => '周${_wd(w)}').join('、');
      case PlanRepeatFrequency.workdays:
        return '工作日';
      case PlanRepeatFrequency.monthly:
        return r.daysOfMonth.map((d) => '$d 日').join('、');
    }
  }

  String _wd(int w) => switch (w) {
        1 => '一',
        2 => '二',
        3 => '三',
        4 => '四',
        5 => '五',
        6 => '六',
        7 => '日',
        _ => '$w',
      };

  String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _fmtDateTime(DateTime? d) {
    if (d == null) return '—';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _fmtDuration(Duration d) {
    final s = d.inSeconds < 0 ? 0 : d.inSeconds;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = sec.toString().padLeft(2, '0');
    if (h > 0) return '$h:$mm:$ss';
    if (m > 0) return '$mm:$ss';
    return '$sec 秒';
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.palette, required this.status});

  final Palette palette;
  final PlanStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      PlanStatus.active => (palette.accent, '进行中'),
      PlanStatus.paused => (const Color(0xFFFFB300), '暂停'),
      PlanStatus.overdue => (const Color(0xFFE53935), '超时'),
      PlanStatus.completed => (const Color(0xFF1FAF58), '完成'),
      PlanStatus.skipped => (palette.secondary, '跳过'),
      PlanStatus.unstarted => (palette.secondary, '未开始'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}

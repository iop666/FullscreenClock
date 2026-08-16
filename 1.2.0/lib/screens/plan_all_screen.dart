import 'package:flutter/material.dart';

import '../models/plan.dart';
import '../providers/plan_provider.dart';
import '../theme/app_theme.dart';
import '../utils/plan_time.dart';
import 'plan_edit_screen.dart';

/// 查看全部 / 所有未完成:支持按日期挑选、关键字搜索、全部/未完成切换。
class PlanAllScreen extends StatefulWidget {
  const PlanAllScreen({
    super.key,
    required this.planProvider,
    required this.palette,
    this.undoneOnly = false,
  });

  final PlanProvider planProvider;
  final Palette palette;
  final bool undoneOnly;

  @override
  State<PlanAllScreen> createState() => _PlanAllScreenState();
}

class _PlanAllScreenState extends State<PlanAllScreen> {
  String _query = '';
  DateTime? _onlyDay;
  late bool _undone;
  String _fType = '';
  String _fTopic = '';
  String _fUnit = '';

  PlanProvider get planProvider => widget.planProvider;
  Palette get palette => widget.palette;

  @override
  void initState() {
    super.initState();
    _undone = widget.undoneOnly;
  }

  List<PlanOccurrence> _all() {
    final plans = planProvider.plans;
    final from = DateTime.now().subtract(const Duration(days: 30));
    final to = DateTime.now().add(const Duration(days: 90));
    return occurrencesInRange(plans, from, to);
  }

  PlanStatus _statusOf(PlanOccurrence occ) {
    final rt = planProvider.runtimeFor(occ);
    if (rt != null) return rt.status;
    final hist = planProvider.history
        .where((h) => h.planId == occ.plan.id && h.dateKey == occ.dateKey)
        .toList();
    if (hist.isNotEmpty) return hist.first.finalStatus;
    return PlanStatus.unstarted;
  }

  bool _passes(PlanOccurrence occ) {
    if (_onlyDay != null && !sameDay(occ.day, _onlyDay!)) return false;
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      final hay =
          '${occ.plan.title} ${occ.plan.notes}'.toLowerCase();
      if (!hay.contains(q)) return false;
    }
    // 三级筛选:类型/主题/单元
    if (_fType.isNotEmpty && occ.plan.type != _fType) return false;
    if (_fTopic.isNotEmpty && occ.plan.topic != _fTopic) return false;
    if (_fUnit.isNotEmpty && occ.plan.unit != _fUnit) return false;
    if (_undone && _statusOf(occ) == PlanStatus.completed) return false;
    return true;
  }

  List<String> _uniqueType() => _uniqueOf((p) => p.type);
  List<String> _uniqueTopic() => _uniqueOf((p) => p.topic);
  List<String> _uniqueUnit() => _uniqueOf((p) => p.unit);

  List<String> _uniqueOf(String Function(Plan p) sel) {
    final s = <String>{};
    for (final p in planProvider.plans) {
      final v = sel(p).trim();
      if (v.isNotEmpty) s.add(v);
    }
    return s.toList()..sort();
  }

  Widget _filterDrop(String label, String value, List<String> options,
      ValueChanged<String> onChanged) {
    return DropdownButton<String>(
      value: value,
      isDense: true,
      underline: const SizedBox.shrink(),
      dropdownColor: palette.card,
      icon: Icon(Icons.arrow_drop_down, color: palette.accent),
      style: TextStyle(color: palette.foreground, fontSize: 12),
      items: [
        DropdownMenuItem(
          value: '',
          child: Text('全部$label',
              style: TextStyle(color: palette.secondary, fontSize: 12)),
        ),
        for (final o in options)
          DropdownMenuItem(
            value: o,
            child: Text(o,
                style: TextStyle(color: palette.foreground, fontSize: 12)),
          ),
      ],
      onChanged: (v) => onChanged(v ?? ''),
    );
  }

  Future<void> _pickDay() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _onlyDay ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (d != null) setState(() => _onlyDay = d);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: planProvider,
      builder: (context, _) {
        final occs = _all().where(_passes).toList()
          ..sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));
        return Scaffold(
          backgroundColor: palette.background,
          appBar: AppBar(
            backgroundColor: palette.background,
            foregroundColor: palette.foreground,
            elevation: 0,
            title: Text(_undone ? '所有未完成' : '查看全部',
                style: TextStyle(color: palette.foreground)),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: TextField(
                  style: TextStyle(color: palette.foreground),
                  decoration: InputDecoration(
                    hintText: '搜索计划标题或内容',
                    hintStyle: TextStyle(color: palette.secondary),
                    prefixIcon: Icon(Icons.search, color: palette.secondary),
                    isDense: true,
                    filled: true,
                    fillColor: palette.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: palette.cardBorder),
                    ),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    _filterDrop('类型', _fType, _uniqueType(),
                        (v) => setState(() => _fType = v)),
                    _filterDrop('主题', _fTopic, _uniqueTopic(),
                        (v) => setState(() => _fTopic = v)),
                    _filterDrop('单元', _fUnit, _uniqueUnit(),
                        (v) => setState(() => _fUnit = v)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
                child: Row(
                  children: [
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('全部')),
                        ButtonSegment(value: true, label: Text('未完成')),
                      ],
                      selected: {_undone},
                      onSelectionChanged: (s) =>
                          setState(() => _undone = s.first),
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
                        side: WidgetStatePropertyAll(
                            BorderSide(color: palette.cardBorder)),
                        visualDensity: VisualDensity.compact,
                        textStyle: WidgetStatePropertyAll(
                            const TextStyle(fontSize: 12)),
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _pickDay,
                      icon: Icon(Icons.calendar_today,
                          size: 15, color: palette.accent),
                      label: Text(
                        _onlyDay == null ? '全部日期' : _fmtDate(_onlyDay!),
                        style: TextStyle(color: palette.accent, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: occs.isEmpty
                    ? Center(
                        child: Text('没有匹配的计划',
                            style:
                                TextStyle(color: palette.secondary, fontSize: 15)),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: occs.length,
                        itemBuilder: (context, i) =>
                            _row(context, occs[i]),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _row(BuildContext context, PlanOccurrence occ) {
    final st = _statusOf(occ);
    final done = st == PlanStatus.completed;
    final c = done
        ? palette.secondary.withValues(alpha: 0.6)
        : Color(occ.plan.color);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openEdit(context, occ.plan),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 34,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    occ.plan.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: done ? c : palette.foreground,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${_fmtDate(occ.day)} ${_hhmm(occ.scheduledStart)} - ${_hhmm(occ.scheduledEnd)}',
                    style: TextStyle(
                        color: done ? c : palette.secondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            _StatusDot(palette: palette, status: st),
            PopupMenuButton<String>(
              color: palette.card,
              onSelected: (v) => switch (v) {
                'edit' => _openEdit(context, occ.plan),
                'del' => _delete(context, occ),
                _ => null,
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Text('修改计划',
                      style: TextStyle(color: palette.foreground)),
                ),
                PopupMenuItem(
                  value: 'del',
                  child: Text('删除',
                      style: TextStyle(color: Color(0xFFE53935))),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openEdit(BuildContext context, Plan plan) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PlanEditScreen(
        planProvider: planProvider,
        palette: palette,
        plan: plan,
      ),
    ));
  }

  Future<void> _delete(BuildContext context, PlanOccurrence occ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.card,
        title: Text('删除计划',
            style: TextStyle(color: palette.foreground)),
        content: Text('确定删除「${occ.plan.title}」吗?',
            style: TextStyle(color: palette.foreground)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('取消', style: TextStyle(color: palette.secondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除',
                style: TextStyle(color: Color(0xFFE53935))),
          ),
        ],
      ),
    );
    if (ok == true) {
      planProvider.deletePlan(occ.plan.id);
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.palette, required this.status});

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

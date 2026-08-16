import 'package:flutter/material.dart';

import '../models/plan.dart';
import '../models/plan_conflict.dart';
import '../models/plan_repeat.dart';
import '../providers/plan_provider.dart';
import '../theme/app_theme.dart';
import '../utils/plan_time.dart';
import '../widgets/plan_candidate_picker.dart';

/// 计划编辑/新建页
class PlanEditScreen extends StatefulWidget {
  const PlanEditScreen({
    super.key,
    required this.planProvider,
    required this.palette,
    this.plan,
  });

  final PlanProvider planProvider;
  final Palette palette;

  /// 编辑已有计划时为非空
  final Plan? plan;

  @override
  State<PlanEditScreen> createState() => _PlanEditScreenState();
}

const List<Color> _kColors = [
  Color(0xFF3B6EF6), // 蓝
  Color(0xFF1FAF58), // 绿
  Color(0xFFE53935), // 红
  Color(0xFFFFB300), // 橙
  Color(0xFF8E44AD), // 紫
  Color(0xFF00ACC1), // 青
  Color(0xFFF06292), // 粉
  Color(0xFF795548), // 棕
  Color(0xFF9E9E9E), // 灰
  Color(0xFF4CAF50), // 草绿
  Color(0xFFFF7043), // 深橙
  Color(0xFF26A69A), // 墨绿
  Color(0xFF5C6BC0), // 靛蓝
  Color(0xFFEC407A), // 玫红
  Color(0xFFD4E157), // 黄绿
  Color(0xFF29B6F6), // 天蓝
  Color(0xFF7E57C2), // 深紫
  Color(0xFFFFCA28), // 琥珀
  Color(0xFFA1887F), // 卡其
  Color(0xFF90A4AE), // 蓝灰
  Color(0xFFF48FB1), // 浅粉
  Color(0xFF66BB6A), // 亮绿
  Color(0xFF00838F), // 深青
  Color(0xFFD84315), // 深红棕
];

const List<int> _kReminderChoices = [0, 5, 10, 15, 30, 60];

class _PlanEditScreenState extends State<PlanEditScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _typeCtrl;
  late final TextEditingController _topicCtrl;
  late final TextEditingController _unitCtrl;
  final TextEditingController _durationCtrl = TextEditingController();

  late int _color;
  late String _iconName;
  late List<String> _tags;
  late DateTime _date;
  late TimeOfDay _time;
  late int _durationMin;
  late RepeatRule _repeat;
  late ProgressType _progressType;
  late List<int> _reminders;

  bool get _editing => widget.plan != null;

  @override
  void initState() {
    super.initState();
    final p = widget.plan;
    _titleCtrl = TextEditingController(text: p?.title ?? '');
    _notesCtrl = TextEditingController(text: p?.notes ?? '');
    _typeCtrl = TextEditingController(text: p?.type ?? '');
    _topicCtrl = TextEditingController(text: p?.topic ?? '');
    _unitCtrl = TextEditingController(text: p?.unit ?? '');
    _color = p?.color ?? _kColors.first.toARGB32();
    _iconName = p?.iconName ?? 'schedule';
    _tags = [...?p?.tags];
    final base = p?.startDate ??
        _nextHour(DateTime.now().add(const Duration(hours: 1)));
    _date = base;
    _time = TimeOfDay(hour: base.hour, minute: base.minute);
    _durationMin = (p?.duration.inMinutes ?? 30).clamp(5, 300).toInt();
    _durationCtrl.text = _durationMin.toString();
    _repeat = p?.repeat ?? const RepeatRule();
    _progressType = p?.progressType ?? ProgressType.automatic;
    _reminders = [...?p?.remindersMinBefore];
    if (_reminders.isEmpty) _reminders = [0, 10];
  }

  DateTime _nextHour(DateTime d) =>
      DateTime(d.year, d.month, d.day, d.hour, 0);

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    _typeCtrl.dispose();
    _topicCtrl.dispose();
    _unitCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  Palette get palette => widget.palette;
  PlanProvider get planProvider => widget.planProvider;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        foregroundColor: palette.foreground,
        elevation: 0,
        title: Text(_editing ? '修改计划' : '新建计划'),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text('保存', style: TextStyle(color: palette.accent)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _sectionTitle('内容'),
          _card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _typeCtrl,
                        style:
                            TextStyle(color: palette.foreground, fontSize: 15),
                        decoration: _dec('计划类型', '一级,如:学习'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _pickFromCandidates,
                      icon: Icon(Icons.playlist_add,
                          size: 16, color: palette.accent),
                      label: Text('候选清单',
                          style:
                              TextStyle(color: palette.accent, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _topicCtrl,
                  style: TextStyle(color: palette.foreground, fontSize: 15),
                  decoration: _dec('计划主题', '二级,如:行测'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _unitCtrl,
                  style: TextStyle(color: palette.foreground, fontSize: 15),
                  decoration: _dec('计划单元', '三级,如:判断推理'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _titleCtrl,
                  style: TextStyle(color: palette.foreground, fontSize: 16),
                  decoration: _dec('计划标题', '如:晨间阅读'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  style: TextStyle(color: palette.foreground, fontSize: 15),
                  decoration: _dec('备注', '可添加说明(锁屏隐藏时不可见)'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in _kColors)
                      _colorDot(c),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final e in kPlanIcons.entries)
                      _iconChoice(e.key, e.value),
                  ],
                ),
                if (_tags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final t in _tags)
                        InputChip(
                          label: Text(t, style: const TextStyle(fontSize: 12)),
                          onDeleted: () => setState(() => _tags.remove(t)),
                          deleteIconColor: palette.secondary,
                          backgroundColor: palette.card,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          _sectionTitle('时间安排'),
          _card(
            Column(
              children: [
                _rowTap(
                  icon: Icons.event,
                  title: '日期',
                  value: '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
                  onTap: _pickDate,
                ),
                _divider(),
                _rowTap(
                  icon: Icons.access_time,
                  title: '开始时间',
                  value: _time.format(context),
                  onTap: _pickTime,
                ),
                _divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('时长(分钟)',
                                style: TextStyle(
                                    color: palette.foreground, fontSize: 15)),
                          ),
                          Text('$_durationMin 分钟',
                              style: TextStyle(
                                  color: palette.secondary, fontSize: 13)),
                        ],
                      ),
                      Slider(
                        value: _durationMin.toDouble(),
                        min: 5,
                        max: 300,
                        divisions: 59,
                        activeColor: palette.accent,
                        inactiveColor: palette.secondary,
                        label: '$_durationMin 分钟',
                        onChanged: (v) => setState(() {
                          _durationMin = v.round();
                          _durationCtrl.text = _durationMin.toString();
                        }),
                      ),
                      TextFormField(
                        controller: _durationCtrl,
                        keyboardType: TextInputType.number,
                        style:
                            TextStyle(color: palette.foreground, fontSize: 14),
                        decoration: _dec('自定义时长(分钟)', '5~300'),
                        onChanged: (text) {
                          final n = int.tryParse(text);
                          if (n != null) {
                            setState(() => _durationMin = n.clamp(5, 300));
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _sectionTitle('重复'),
          _card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _segmented(
                  values: PlanRepeatFrequency.values,
                  selected: _repeat.frequency,
                  labelOf: _freqLabel,
                  onChanged: (v) => setState(() =>
                      _repeat = _repeat.copyWith(frequency: v)),
                ),
                if (_repeat.frequency == PlanRepeatFrequency.weekly ||
                    _repeat.frequency == PlanRepeatFrequency.workdays) ...[
                  const SizedBox(height: 12),
                  Text('每周重复的天', style: _sub()),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (var w = 1; w <= 7; w++)
                        ChoiceChip(
                          label: Text(_weekdayLabel(w), style: const TextStyle(fontSize: 12)),
                          selected: _repeat.daysOfWeek.contains(w),
                          onSelected: (sel) {
                            setState(() {
                              final list = [..._repeat.daysOfWeek];
                              if (sel) {
                                if (!list.contains(w)) list.add(w);
                              } else {
                                list.remove(w);
                              }
                              list.sort();
                              _repeat = _repeat.copyWith(daysOfWeek: list);
                            });
                          },
                          selectedColor: palette.foreground,
                          backgroundColor: palette.card,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            color: _repeat.daysOfWeek.contains(w)
                                ? palette.background
                                : palette.foreground,
                          ),
                          showCheckmark: false,
                        ),
                    ],
                  ),
                ],
                if (_repeat.frequency == PlanRepeatFrequency.monthly) ...[
                  const SizedBox(height: 12),
                  Text('每月日期(逗号分隔,负数表示月末倒数,-1=最后一天)',
                      style: _sub()),
                  const SizedBox(height: 6),
                  TextFormField(
                    initialValue: _repeat.daysOfMonth.isEmpty
                        ? '1'
                        : _repeat.daysOfMonth.join(','),
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: palette.foreground, fontSize: 14),
                    decoration: _dec('如:1,15,20 或 -1'),
                    onChanged: (text) {
                      final parsed = text
                          .split(RegExp(r'[,，\s]+'))
                          .where((s) => s.isNotEmpty)
                          .map(int.tryParse)
                          .whereType<int>()
                          .toList();
                      setState(() =>
                          _repeat = _repeat.copyWith(daysOfMonth: parsed));
                    },
                  ),
                ],
                if (_repeat.frequency != PlanRepeatFrequency.none) ...[
                  const SizedBox(height: 12),
                  Text('重复间隔', style: _sub()),
                  _sliderRow(
                    title: '每 ${_repeat.interval} $_intervalUnit重复',
                    slider: Slider(
                      value: _repeat.interval.toDouble(),
                      min: 1,
                      max: 30,
                      divisions: 29,
                      activeColor: palette.accent,
                      inactiveColor: palette.secondary,
                      onChanged: (v) => setState(
                          () => _repeat = _repeat.copyWith(interval: v.round())),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('结束条件', style: _sub()),
                  const SizedBox(height: 6),
                  _segmented(
                    values: RepeatEndCondition.values,
                    selected: _repeat.endType,
                    labelOf: (e) => switch (e) {
                      RepeatEndCondition.never => '无期限',
                      RepeatEndCondition.until => '直到某天',
                      RepeatEndCondition.count => '重复 N 次',
                    },
                    onChanged: (v) => setState(() => _repeat = _repeat.copyWith(endType: v)),
                  ),
                  if (_repeat.endType == RepeatEndCondition.until) ...[
                    const SizedBox(height: 8),
                    _rowTap(
                      icon: Icons.event,
                      title: '结束日期',
                      value: _repeat.untilDate == null
                          ? '选择'
                          : '${_repeat.untilDate!.year}-${_repeat.untilDate!.month.toString().padLeft(2, '0')}-${_repeat.untilDate!.day.toString().padLeft(2, '0')}',
                      onTap: _pickUntilDate,
                    ),
                  ],
                  if (_repeat.endType == RepeatEndCondition.count) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: _repeat.repeatCount?.toString() ?? '10',
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: palette.foreground, fontSize: 14),
                      decoration: _dec('重复次数'),
                      onChanged: (text) => setState(() => _repeat =
                          _repeat.copyWith(repeatCount: int.tryParse(text))),
                    ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          _sectionTitle('提醒'),
          _card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final m in _kReminderChoices)
                      ChoiceChip(
                        label: Text(m == 0 ? '准时' : '提前 $m 分',
                            style: const TextStyle(fontSize: 12)),
                        selected: _reminders.contains(m),
                        onSelected: (sel) => setState(() {
                          if (sel) {
                            if (!_reminders.contains(m)) {
                              _reminders = [..._reminders, m]..sort();
                            }
                          } else {
                            _reminders.remove(m);
                          }
                        }),
                        selectedColor: palette.foreground,
                        backgroundColor: palette.card,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          color: _reminders.contains(m)
                              ? palette.background
                              : palette.foreground,
                        ),
                        showCheckmark: false,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('可多选,到点前触发通知', style: _sub()),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _sectionTitle('进度'),
          _card(
            Column(
              children: [
                _segmented(
                  values: const [ProgressType.automatic, ProgressType.none],
                  selected: _progressType,
                  labelOf: (p) => switch (p) {
                    ProgressType.automatic => '按时间自动',
                    ProgressType.manual => '开始后手动',
                    ProgressType.none => '不设置进度',
                  },
                  onChanged: (v) => setState(() => _progressType = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.accent,
              side: BorderSide(color: palette.accent),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: const Text('保存计划'),
          ),
        ],
      ),
    );
  }

  // ---- 交互 ----

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (t != null) setState(() => _time = t);
  }

  Future<void> _pickUntilDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _repeat.untilDate ?? _date.add(const Duration(days: 30)),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (d != null) {
      setState(() => _repeat = _repeat.copyWith(untilDate: d));
    }
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      _toast('请填写计划标题');
      return;
    }
    if (_durationMin < 5) {
      _toast('时长至少 5 分钟');
      return;
    }
    if (_repeat.frequency == PlanRepeatFrequency.weekly &&
        _repeat.daysOfWeek.isEmpty) {
      _toast('请选择每周重复的天');
      return;
    }

    final startDate = DateTime(_date.year, _date.month, _date.day,
        _time.hour, _time.minute);
    final plan = Plan(
      id: _editing ? widget.plan!.id : newPlanId(),
      title: title,
      type: _typeCtrl.text.trim(),
      topic: _topicCtrl.text.trim(),
      unit: _unitCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      color: _color,
      iconName: _iconName,
      tags: _tags,
      startDate: startDate,
      duration: Duration(minutes: _durationMin),
      repeat: _repeat,
      progressType: _progressType,
      remindersMinBefore: _reminders,
      notificationEnabled: true,
      channel: PlanChannel.start,
      lockVisibility: planProvider.defaultLockVisibility,
      order: _editing ? widget.plan!.order : planProvider.plans.length,
    );

    // 修改时时间是否变化(仅改内容/备注则为 false)
    final timeChanged = _editing &&
        (startDate != widget.plan!.startDate ||
            Duration(minutes: _durationMin) != widget.plan!.duration);
    // 仅改内容(未改时间):以 provider 最新计划的时间保存
    // (避免自动顺延导致编辑快照与最新不一致而产生重叠)
    var finalPlan = plan;
    if (_editing && !timeChanged) {
      final latest = planProvider.planById(widget.plan!.id);
      if (latest != null) {
        finalPlan = plan.copyWith(
            startDate: latest.startDate, duration: latest.duration);
      }
    }

    // 冲突检测:覆盖未来 60 天内所有可能实例(含重复计划),确保不与任何计划重叠
    final allPlans = [
      if (_editing)
        for (final p in planProvider.plans)
          if (p.id != finalPlan.id) p
      else
        ...planProvider.plans,
      finalPlan,
    ];
    final from = startOfDay(finalPlan.startDate);
    final report = detectConflicts(
        occurrencesInRange(allPlans, from, from.add(const Duration(days: 60))));
    if (_editing) {
      // 修改:时间变化时必须不与其它计划重叠;时间未变(仅改内容)→ 允许先删后加
      if (timeChanged) {
        final mine = report.issues
            .where((i) =>
                i.planId == finalPlan.id || i.otherPlanId == finalPlan.id)
            .toList();
        if (mine.isNotEmpty) {
          _showConflict(ConflictReport(mine), blocking: true);
          return;
        }
      }
    } else if (report.hasBlocking) {
      // 新建:任何冲突(重叠/非法)都拦截,不允许同时段有其他计划
      _showConflict(report, blocking: true);
      return;
    }

    if (_editing) {
      // 修改计划:先删除修改前的计划,再保存修改后的计划
      planProvider.deletePlan(widget.plan!.id);
      // 时间未变(仅改内容)→ 跳过冲突检测,保留既有状态
      final err =
          planProvider.addPlan(finalPlan, skipConflictCheck: !timeChanged);
      if (err != null) {
        // 兜底:addPlan 拒绝(理论已拦截),恢复原计划
        planProvider.addPlan(widget.plan!, skipConflictCheck: true);
        _toast('保存失败:$err');
        return;
      }
      _toast('修改完成');
    } else {
      final err = planProvider.addPlan(finalPlan);
      if (err != null) {
        _showConflict(
            ConflictReport([
              ConflictIssue(
                  type: ConflictType.overlap,
                  planId: plan.id,
                  message: err,
                  blocking: true)
            ]),
            blocking: true);
        return;
      }
      _toast('添加完成');
    }
    if (mounted) Navigator.of(context).pop();
  }

  /// 从候选清单选择(文件管理器式逐级浏览),自动填充 类型/主题/单元/标题
  void _pickFromCandidates() {
    if (planProvider.candidates.isEmpty) {
      _toast('候选清单为空,请先在 设置→计划→候选清单 中添加或导入');
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.card,
      isScrollControlled: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.7,
        child: PlanCandidatePicker(
          planProvider: planProvider,
          palette: palette,
          onPicked: (c) {
            Navigator.of(ctx).pop();
            setState(() {
              _typeCtrl.text = c.type;
              _topicCtrl.text = c.topic;
              _unitCtrl.text = c.unit;
              _titleCtrl.text = c.title;
            });
          },
        ),
      ),
    );
  }

  void _showConflict(ConflictReport report, {required bool blocking}) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.card,
        title: Text(blocking ? '无法保存' : '计划冲突'),
        content: Text(
          report.messages.join('\n'),
          style: TextStyle(color: palette.foreground),
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

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---- 布局辅助 ----

  Widget _sectionTitle(String text) => Padding(
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

  Widget _card(Widget child) => Container(
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.cardBorder),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: child,
      );

  Widget _divider() =>
      Divider(height: 1, thickness: 1, color: palette.cardBorder);

  TextStyle _sub() =>
      TextStyle(color: palette.secondary, fontSize: 12);

  InputDecoration _dec(String label, [String? hint]) => InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: _sub(),
        hintStyle: _sub(),
        isDense: true,
        filled: true,
        fillColor: palette.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: palette.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: palette.cardBorder),
        ),
      );

  Widget _rowTap({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: palette.accent),
      title: Text(title, style: TextStyle(color: palette.foreground, fontSize: 15)),
      subtitle: Text(value, style: TextStyle(color: palette.secondary, fontSize: 13)),
      trailing: Icon(Icons.chevron_right, color: palette.secondary),
      onTap: onTap,
    );
  }

  Widget _sliderRow({
    required String title,
    required Widget slider,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(color: palette.foreground, fontSize: 15)),
          slider,
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
        textStyle: WidgetStatePropertyAll(const TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _colorDot(Color c) {
    final selected = _color == c.toARGB32();
    return GestureDetector(
      onTap: () => setState(() => _color = c.toARGB32()),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? palette.foreground : c.withValues(alpha: 0.5),
            width: selected ? 3 : 1,
          ),
        ),
        child: selected
            ? Icon(Icons.check, color: _contrast(c), size: 18)
            : null,
      ),
    );
  }

  Widget _iconChoice(String name, IconData icon) {
    final selected = _iconName == name;
    return GestureDetector(
      onTap: () => setState(() => _iconName = name),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: selected ? palette.foreground : palette.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? palette.foreground : palette.cardBorder,
          ),
        ),
        child: Icon(icon, color: selected ? palette.background : palette.foreground, size: 20),
      ),
    );
  }

  Color _contrast(Color c) =>
      c.computeLuminance() > 0.5 ? Colors.black : Colors.white;

  String _freqLabel(PlanRepeatFrequency f) => switch (f) {
        PlanRepeatFrequency.none => '不重复',
        PlanRepeatFrequency.daily => '每天',
        PlanRepeatFrequency.weekly => '每周',
        PlanRepeatFrequency.workdays => '工作日',
        PlanRepeatFrequency.monthly => '每月',
      };

  String _weekdayLabel(int w) => switch (w) {
        1 => '一',
        2 => '二',
        3 => '三',
        4 => '四',
        5 => '五',
        6 => '六',
        7 => '日',
        _ => '$w',
      };

  String get _intervalUnit => switch (_repeat.frequency) {
        PlanRepeatFrequency.daily => '天',
        PlanRepeatFrequency.weekly => '周',
        PlanRepeatFrequency.workdays => '周',
        PlanRepeatFrequency.monthly => '月',
        PlanRepeatFrequency.none => '',
      };
}

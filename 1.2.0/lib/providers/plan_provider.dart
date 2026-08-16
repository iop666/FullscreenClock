import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/plan.dart';
import '../models/plan_candidate.dart';
import '../models/plan_conflict.dart';
import '../models/plan_history.dart';
import '../utils/plan_time.dart';

/// 提醒触发回调(由通知服务注册;M1/M2 接通知)
typedef ReminderCallback = void Function(PlanOccurrence occ, int minBefore);

/// 计划状态管理:数据 CRUD + 状态机 + 持久化 + 冲突检测编排。
/// 复刻 SettingsProvider 的持久化惯例;通知/闹钟通过回调注入(保持可单测)。
class PlanProvider extends ChangeNotifier {
  PlanProvider(this._prefs);

  final SharedPreferences _prefs;

  List<Plan> _plans = [];
  Map<String, PlanRuntime> _runtimes = {};
  List<PlanHistoryRecord> _history = [];

  /// 撤销栈:每个计划 id → 该实例最近操作前的 runtime 快照
  final Map<String, List<PlanRuntime>> _undoStacks = {};

  bool _enabled = false;
  bool _persistentNotif = true;
  bool _startNotif = true;
  bool _overdueNotif = true;
  bool _reminderNotif = true;
  LockScreenVisibility _defaultLockVisibility = LockScreenVisibility.public;
  double _overlayScale = 1.0;

  // 主界面计划模块显示设置
  String _moduleAlign = 'center'; // center/bottomLeft/bottomRight/stretch
  bool _moduleSplit = false; // false=底部横条,true=时钟靠左2/3+计划靠右1/3
  String _moduleTime = 'remaining'; // elapsed/remaining/both
  bool _moduleShowProgress = true;
  bool _moduleShowIcon = true;
  bool _moduleStrokePlanColor = false; // false=进行中描边用默认色,true=用计划颜色
  bool _moduleShowColor = false; // 显示进度环前的计划颜色条
  bool _moduleIconPlanColor = false; // 图标颜色使用计划颜色
  List<PlanCandidate> _candidates = [];

  /// 本次运行已触发过的提醒(防重复)
  final Set<String> _firedReminders = {};

  /// onTick 内部计数(每 30 次刷新常驻通知)
  int _tickCount = 0;

  // ---- 通知/闹钟回调(由 main.dart 注入) ----
  ReminderCallback? reminderCallback;

  /// 状态迁移(通知服务据此发开始/超时等提醒)
  void Function(PlanOccurrence occ, PlanStatus oldStatus, PlanStatus newStatus)?
      onStatusChanged;

  /// 常驻通知周期刷新(约每 30 秒)
  void Function(DateTime now)? persistentTickCallback;

  /// 闹钟调度刷新(计划/状态变化后重排未来事件)
  void Function()? schedulingCallback;

  /// Windows 端应用内提醒(ClockScreen 注册 SnackBar)
  void Function(String message)? windowsNoticeCallback;

  // ---- SharedPreferences keys ----
  static const _kEnabled = 'plan_enabled';
  static const _kPlans = 'plan_list';
  static const _kRuntimes = 'plan_runtimes';
  static const _kHistory = 'plan_history';
  static const _kPersistentNotif = 'plan_notif_persistent';
  static const _kStartNotif = 'plan_notif_start';
  static const _kOverdueNotif = 'plan_notif_overdue';
  static const _kReminderNotif = 'plan_notif_reminder';
  static const _kLockVisibility = 'plan_lock_visibility';
  static const _kOverlayScale = 'plan_overlay_scale';
  static const _kModuleAlign = 'plan_module_align';
  static const _kModuleSplit = 'plan_module_split';
  static const _kModuleTime = 'plan_module_time';
  static const _kModuleShowProgress = 'plan_module_show_progress';
  static const _kModuleShowIcon = 'plan_module_show_icon';
  static const _kModuleStrokePlanColor = 'plan_module_stroke_plan_color';
  static const _kModuleShowColor = 'plan_module_show_color';
  static const _kModuleIconPlanColor = 'plan_module_icon_plan_color';
  static const _kCandidates = 'plan_candidates';

  // ---- getters ----
  List<Plan> get plans => List.unmodifiable(_plans);
  Map<String, PlanRuntime> get runtimes => Map.unmodifiable(_runtimes);
  List<PlanHistoryRecord> get history => List.unmodifiable(_history);
  bool get enabled => _enabled;
  bool get persistentNotif => _persistentNotif;
  bool get startNotif => _startNotif;
  bool get overdueNotif => _overdueNotif;
  bool get reminderNotif => _reminderNotif;
  LockScreenVisibility get defaultLockVisibility => _defaultLockVisibility;
  double get overlayScale => _overlayScale;
  String get moduleAlign => _moduleAlign;
  bool get moduleSplit => _moduleSplit;
  String get moduleTime => _moduleTime;
  bool get moduleShowProgress => _moduleShowProgress;
  bool get moduleShowIcon => _moduleShowIcon;
  bool get moduleStrokePlanColor => _moduleStrokePlanColor;
  bool get moduleShowColor => _moduleShowColor;
  bool get moduleIconPlanColor => _moduleIconPlanColor;
  List<PlanCandidate> get candidates => List.unmodifiable(_candidates);

  // ---- 加载 ----
  static Future<PlanProvider> load() async {
    final prefs = await SharedPreferences.getInstance();
    final p = PlanProvider(prefs);
    p._enabled = prefs.getBool(_kEnabled) ?? false;
    p._persistentNotif = prefs.getBool(_kPersistentNotif) ?? true;
    p._startNotif = prefs.getBool(_kStartNotif) ?? true;
    p._overdueNotif = prefs.getBool(_kOverdueNotif) ?? true;
    p._reminderNotif = prefs.getBool(_kReminderNotif) ?? true;
    p._defaultLockVisibility = _enumByIndex(
        prefs.getInt(_kLockVisibility), LockScreenVisibility.values,
        LockScreenVisibility.public);
    p._overlayScale = prefs.getDouble(_kOverlayScale) ?? 1.0;
    p._moduleAlign = prefs.getString(_kModuleAlign) ?? 'center';
    p._moduleSplit = prefs.getBool(_kModuleSplit) ?? false;
    p._moduleTime = prefs.getString(_kModuleTime) ?? 'remaining';
    p._moduleShowProgress = prefs.getBool(_kModuleShowProgress) ?? true;
    p._moduleShowIcon = prefs.getBool(_kModuleShowIcon) ?? true;
    p._moduleStrokePlanColor =
        prefs.getBool(_kModuleStrokePlanColor) ?? false;
    p._moduleShowColor = prefs.getBool(_kModuleShowColor) ?? false;
    p._moduleIconPlanColor =
        prefs.getBool(_kModuleIconPlanColor) ?? false;
    p._candidates = (prefs.getStringList(_kCandidates) ?? const [])
        .map((s) =>
            PlanCandidate.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
    p._plans = (prefs.getStringList(_kPlans) ?? const [])
        .map((s) => Plan.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
    p._runtimes = {
      for (final s in prefs.getStringList(_kRuntimes) ?? const [])
        (() {
          final r = PlanRuntime.fromJson(jsonDecode(s) as Map<String, dynamic>);
          return '${r.planId}|${r.dateKey}';
        })(): PlanRuntime.fromJson(jsonDecode(s) as Map<String, dynamic>),
    };
    p._history = (prefs.getStringList(_kHistory) ?? const [])
        .map((s) => PlanHistoryRecord.fromJson(
            jsonDecode(s) as Map<String, dynamic>))
        .toList();
    p._reconcileOnLoad(DateTime.now());
    return p;
  }

  static T _enumByIndex<T extends Enum>(int? index, List<T> values, T fallback) {
    if (index == null || index < 0 || index >= values.length) return fallback;
    return values[index];
  }

  // ---- 开关 ----
  void setEnabled(bool value) {
    _enabled = value;
    _prefs.setBool(_kEnabled, value);
    if (!value) {
      // 关闭时停止服务与闹钟
      schedulingCallback?.call();
    }
    notifyListeners();
  }

  void setPersistentNotif(bool v) {
    _persistentNotif = v;
    _prefs.setBool(_kPersistentNotif, v);
    schedulingCallback?.call(); // 同步前台服务启停
    persistentTickCallback?.call(DateTime.now());
    notifyListeners();
  }

  void setStartNotif(bool v) {
    _startNotif = v;
    _prefs.setBool(_kStartNotif, v);
    notifyListeners();
  }

  void setOverdueNotif(bool v) {
    _overdueNotif = v;
    _prefs.setBool(_kOverdueNotif, v);
    notifyListeners();
  }

  void setReminderNotif(bool v) {
    _reminderNotif = v;
    _prefs.setBool(_kReminderNotif, v);
    notifyListeners();
  }

  void setOverlayScale(double v) {
    _overlayScale = v.clamp(0.5, 2.0);
    _prefs.setDouble(_kOverlayScale, _overlayScale);
    notifyListeners();
  }

  void setModuleAlign(String v) {
    _moduleAlign = v;
    _prefs.setString(_kModuleAlign, v);
    notifyListeners();
  }

  void setModuleSplit(bool v) {
    _moduleSplit = v;
    _prefs.setBool(_kModuleSplit, v);
    notifyListeners();
  }

  void setModuleTime(String v) {
    _moduleTime = v;
    _prefs.setString(_kModuleTime, v);
    notifyListeners();
  }

  void setModuleShowProgress(bool v) {
    _moduleShowProgress = v;
    _prefs.setBool(_kModuleShowProgress, v);
    notifyListeners();
  }

  void setModuleShowIcon(bool v) {
    _moduleShowIcon = v;
    _prefs.setBool(_kModuleShowIcon, v);
    notifyListeners();
  }

  void setModuleStrokePlanColor(bool v) {
    _moduleStrokePlanColor = v;
    _prefs.setBool(_kModuleStrokePlanColor, v);
    notifyListeners();
  }

  void setModuleShowColor(bool v) {
    _moduleShowColor = v;
    _prefs.setBool(_kModuleShowColor, v);
    notifyListeners();
  }

  void setModuleIconPlanColor(bool v) {
    _moduleIconPlanColor = v;
    _prefs.setBool(_kModuleIconPlanColor, v);
    notifyListeners();
  }

  // ---- 计划 CRUD ----

  /// 添加计划;若与现有计划在未来 60 天内有时间重叠,返回错误消息且不添加(兜底拦截)。
  /// [skipConflictCheck] 为 true 时跳过检测(供「修改仅改内容保留既有重叠」使用)。
  String? addPlan(Plan plan, {bool skipConflictCheck = false}) {
    if (!skipConflictCheck) {
      final msg = _overlapMessage(plan);
      if (msg != null) return msg;
    }
    _plans = [..._plans, plan];
    _savePlans();
    _refreshScheduling(DateTime.now());
    notifyListeners();
    return null;
  }

  /// 检测 plan 与现有计划(除自身)在未来 60 天内的时间重叠;无冲突返回 null
  String? _overlapMessage(Plan plan) {
    final others = [
      for (final p in _plans)
        if (p.id != plan.id) p,
      plan,
    ];
    final from = startOfDay(plan.startDate);
    final report = detectConflicts(
        occurrencesInRange(others, from, from.add(const Duration(days: 60))));
    final mine = report.issues
        .where((i) => i.planId == plan.id || i.otherPlanId == plan.id)
        .toList();
    if (mine.isEmpty) return null;
    return mine.first.message;
  }

  void updatePlan(Plan plan) {
    _plans = [
      for (final p in _plans) p.id == plan.id ? plan : p,
    ];
    _savePlans();
    _refreshScheduling(DateTime.now());
    notifyListeners();
  }

  void deletePlan(String id) {
    _plans = _plans.where((p) => p.id != id).toList();
    _runtimes.removeWhere((k, _) => k.startsWith('$id|'));
    _savePlans();
    _saveRuntimes();
    _refreshScheduling(DateTime.now());
    notifyListeners();
  }

  /// 取消运行状态:清除该计划的所有 runtime(回到未开始),后续不再自动激活
  void cancelRunning(String planId, DateTime now) {
    _runtimes.removeWhere((k, _) => k.startsWith('$planId|'));
    _saveRuntimes();
    _refreshScheduling(now);
    notifyListeners();
  }

  // ---- 候选清单(四级结构:类型→主题→单元→标题)----

  void _saveCandidates() {
    _prefs.setStringList(_kCandidates,
        [for (final c in _candidates) jsonEncode(c.toJson())]);
  }

  void addCandidate(PlanCandidate c) {
    _candidates = [..._candidates, c];
    _saveCandidates();
    notifyListeners();
  }

  void removeCandidate(String key) {
    _candidates = _candidates.where((c) => c.key != key).toList();
    _saveCandidates();
    notifyListeners();
  }

  void clearCandidates() {
    _candidates = [];
    _saveCandidates();
    notifyListeners();
  }

  /// 导入候选清单 JSON(参考计划导入);返回错误消息或 null(成功)
  String? importCandidatesContent(String content) {
    try {
      final root = jsonDecode(content) as Map<String, dynamic>;
      final raw = root['candidates'];
      if (raw is! List) return '候选清单 JSON 缺少 candidates 数组';
      final list = <PlanCandidate>[];
      for (final item in raw) {
        if (item is Map) {
          final m = item.cast<String, dynamic>();
          final t = m['title'] as String? ?? '';
          if (t.trim().isEmpty) continue;
          list.add(PlanCandidate.fromJson(m));
        }
      }
      if (list.isEmpty) return '没有可导入的候选条目';
      _candidates = [..._candidates, ...list];
      _saveCandidates();
      notifyListeners();
      return null;
    } catch (_) {
      return '候选清单 JSON 解析失败';
    }
  }

  /// 导出候选清单 JSON 字符串
  String exportCandidatesContent() {
    return const JsonEncoder.withIndent('  ').convert({
      'schemaVersion': '1.0.0',
      'candidates': [for (final c in _candidates) c.toJson()],
    });
  }

  /// 整体平移计划(提前=负、延后=正):开始与结束时间一起平移,时长不变。
  /// 若平移后与其它计划时间重叠,返回错误消息且不移动。
  String? movePlan(String planId, Duration delta) {
    final target = _planById(planId);
    if (target == null) return null;
    final moved = target.copyWith(startDate: target.startDate.add(delta));
    final msg = _overlapMessage(moved);
    if (msg != null) return msg;
    _plans = [for (final p in _plans) p.id == planId ? moved : p];
    _savePlans();
    _refreshScheduling(DateTime.now());
    notifyListeners();
    return null;
  }

  /// 连锁延后:当前计划继续(可能超时)时,后续计划按「当前结束 + 1 分钟」逐级顺延;
  /// 有空闲间隔(未超过)则不影响该计划。超时进行中时以当前时刻为实际结束参考(随推进顺延)。
  void cascadeDelay(PlanOccurrence current, PlanRuntime rt, DateTime now) {
    var curEnd = effectiveEnd(current, rt, now);
    if (curEnd.isBefore(now)) curEnd = now; // 超时中:后续随当前实际时间顺延
    var requiredStart = curEnd.add(const Duration(minutes: 1));
    final later = todayOccurrences(now)
        .where((o) =>
            o.plan.id != current.plan.id &&
            o.scheduledStart.isAfter(current.scheduledStart))
        .toList()
      ..sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));
    for (final n in later) {
      if (n.scheduledStart.isBefore(requiredStart)) {
        final d = requiredStart.difference(n.scheduledStart);
        movePlan(n.plan.id, d);
        requiredStart = n.scheduledEnd.add(d);
      } else {
        requiredStart = n.scheduledEnd;
      }
    }
  }

  // ---- 撤销 ----

  bool canUndo(String planId) => (_undoStacks[planId]?.length ?? 0) > 0;

  /// 记录某实例操作前的运行状态快照(供撤销)
  void _pushUndo(String planId, PlanRuntime? rt) {
    if (rt == null) return;
    final stack = _undoStacks.putIfAbsent(planId, () => []);
    stack.add(rt.copyWith(
      pauseHistory: [...rt.pauseHistory],
      adjustments: [...rt.adjustments],
    ));
    if (stack.length > 50) stack.removeAt(0);
  }

  /// 撤销上一步:恢复该计划最近一次操作前的运行状态
  bool undoLast(String planId, DateTime now) {
    final stack = _undoStacks[planId];
    if (stack == null || stack.isEmpty) return false;
    final prev = stack.removeLast();
    final key = '${prev.planId}|${prev.dateKey}';
    // 若当前已归档(完成/跳过),先移除对应历史记录
    _history = _history
        .where((h) => !(h.planId == planId && h.dateKey == prev.dateKey))
        .toList();
    _saveHistory();
    _runtimes[key] = prev;
    _saveRuntimes();
    _refreshScheduling(now);
    notifyListeners();
    return true;
  }

  // ---- 状态机操作 ----

  /// 开始计划(手动)
  void start(String planId, DateTime now) {
    final occ = _todayOccurrence(planId, now);
    if (occ == null) return;
    final rt = _ensureRuntime(planId, occ.dateKey);
    if (rt.status == PlanStatus.unstarted) {
      _pushUndo(planId, rt);
      _runtimes['$planId|${occ.dateKey}'] =
          rt.copyWith(status: PlanStatus.active, startedAt: now);
      _saveRuntimes();
      _notifyTransition(occ, PlanStatus.unstarted, PlanStatus.active);
    }
  }

  void pause(String planId, DateTime now) {
    final occ = _todayOccurrence(planId, now);
    if (occ == null) return;
    final rt = _runtimeOf(planId, occ.dateKey);
    if (rt == null || rt.status != PlanStatus.active) return;
    _pushUndo(planId, rt);
    _runtimes['$planId|${occ.dateKey}'] = rt.copyWith(
      status: PlanStatus.paused,
      pauseHistory: [
        ...rt.pauseHistory,
        PauseSegment(startedAt: now, reason: '手动暂停'),
      ],
    );
    _saveRuntimes();
    _notifyTransition(occ, PlanStatus.active, PlanStatus.paused);
  }

  void resume(String planId, DateTime now) {
    final occ = _todayOccurrence(planId, now);
    if (occ == null) return;
    final rt = _runtimeOf(planId, occ.dateKey);
    if (rt == null || rt.status != PlanStatus.paused) return;
    _pushUndo(planId, rt);
    final hist = [
      for (final s in rt.pauseHistory)
        s.endedAt == null
            ? PauseSegment(startedAt: s.startedAt, endedAt: now, reason: s.reason)
            : s,
    ];
    final next = rt.copyWith(status: PlanStatus.active, pauseHistory: hist);
    final status =
        effectiveEnd(occ, next, now).isBefore(now)
            ? PlanStatus.overdue
            : PlanStatus.active;
    _runtimes['$planId|${occ.dateKey}'] = next.copyWith(status: status);
    _saveRuntimes();
    _notifyTransition(occ, PlanStatus.paused, status);
  }

  void complete(String planId, DateTime now) {
    final occ = _todayOccurrence(planId, now);
    if (occ == null) return;
    final rt = _runtimeOf(planId, occ.dateKey);
    _pushUndo(planId, rt);
    final target = rt ?? PlanRuntime(planId: planId, dateKey: occ.dateKey);
    final next = target.copyWith(
      status: PlanStatus.completed,
      progress: 1,
      startedAt: target.startedAt ?? now,
      completedAt: now,
    );
    _runtimes['$planId|${occ.dateKey}'] = next;
    _saveRuntimes();
    _archiveIfFinal(occ, now);
    _notifyTransition(occ, target.status, PlanStatus.completed);
  }

  /// 放弃(overdue → skipped)
  void abandon(String planId, DateTime now) {
    final occ = _todayOccurrence(planId, now);
    if (occ == null) return;
    final rt = _runtimeOf(planId, occ.dateKey);
    if (rt == null || rt.status != PlanStatus.overdue) return;
    _pushUndo(planId, rt);
    _runtimes['$planId|${occ.dateKey}'] =
        rt.copyWith(status: PlanStatus.skipped);
    _saveRuntimes();
    _archiveIfFinal(occ, now);
    _notifyTransition(occ, PlanStatus.overdue, PlanStatus.skipped);
  }

  /// 继续并加时(overdue → active),delta 分钟
  void continueAndExtend(String planId, int deltaMinutes, DateTime now) {
    final occ = _todayOccurrence(planId, now);
    if (occ == null) return;
    final rt = _runtimeOf(planId, occ.dateKey);
    if (rt == null || rt.status != PlanStatus.overdue) return;
    _pushUndo(planId, rt);
    final next = rt.copyWith(
      status: PlanStatus.active,
      adjustments: [
        ...rt.adjustments,
        PlanAdjustment(
          type: AdjustmentType.continueAndExtend,
          deltaMinutes: deltaMinutes,
          appliedAt: now,
          note: '继续并加时 $deltaMinutes 分钟',
        ),
      ],
    );
    _runtimes['$planId|${occ.dateKey}'] = next;
    _saveRuntimes();
    _notifyTransition(occ, PlanStatus.overdue, PlanStatus.active);
  }

  /// 加时 delta 分钟(仅延长当前实例,不移动后续计划);
  /// 返回与后续计划重叠的提示列表(若有)。
  List<String> extend(String planId, int deltaMinutes, DateTime now) {
    final occ = _todayOccurrence(planId, now);
    if (occ == null) return const [];
    final rt = _runtimeOf(planId, occ.dateKey);
    if (rt == null ||
        (rt.status != PlanStatus.active &&
            rt.status != PlanStatus.paused &&
            rt.status != PlanStatus.overdue)) {
      return const [];
    }
    _pushUndo(planId, rt);
    _runtimes['$planId|${occ.dateKey}'] = rt.copyWith(
      adjustments: [
        ...rt.adjustments,
        PlanAdjustment(
          type: AdjustmentType.extend,
          deltaMinutes: deltaMinutes,
          appliedAt: now,
          note: '加时 $deltaMinutes 分钟',
        ),
      ],
    );
    _saveRuntimes();
    _refreshScheduling(now);
    return _overlapWarnings(planId, occ, deltaMinutes, now);
  }

  /// 减时 delta 分钟;不允许剩余为负;减时后结束时间≤now → 自动完成。
  List<String> shorten(String planId, int deltaMinutes, DateTime now) {
    final occ = _todayOccurrence(planId, now);
    if (occ == null) return const [];
    final rt = _runtimeOf(planId, occ.dateKey);
    if (rt == null ||
        (rt.status != PlanStatus.active &&
            rt.status != PlanStatus.paused &&
            rt.status != PlanStatus.overdue)) {
      return const [];
    }
    _pushUndo(planId, rt);
    final curEnd = effectiveEnd(occ, rt, now);
    final remaining = curEnd.difference(now);
    var real = deltaMinutes;
    if (remaining.inSeconds < deltaMinutes * 60) {
      real = (remaining.inSeconds / 60).ceil().clamp(0, deltaMinutes);
    }
    final next = rt.copyWith(
      adjustments: [
        ...rt.adjustments,
        PlanAdjustment(
          type: AdjustmentType.shorten,
          deltaMinutes: -real,
          appliedAt: now,
          note: '减时 $real 分钟',
        ),
      ],
    );
    // 减时后结束时间 ≤ now → 自动完成(全局规则)
    if (!effectiveEnd(occ, next, now).isAfter(now)) {
      _runtimes['$planId|${occ.dateKey}'] = next.copyWith(
        status: PlanStatus.completed,
        progress: 1,
        completedAt: now,
      );
      _saveRuntimes();
      _archiveIfFinal(occ, now);
      _notifyTransition(occ, rt.status, PlanStatus.completed);
      return const ['已减至结束时间,计划自动标记为完成'];
    }
    _runtimes['$planId|${occ.dateKey}'] = next;
    _saveRuntimes();
    _refreshScheduling(now);
    return const [];
  }

  /// 手动调整进度(0..1),仅 manual 类型生效
  void setProgress(String planId, double value, DateTime now) {
    final occ = _todayOccurrence(planId, now);
    if (occ == null) return;
    final rt = _ensureRuntime(planId, occ.dateKey);
    _pushUndo(planId, rt);
    final p = occ.plan.progressType == ProgressType.manual
        ? value.clamp(0.0, 1.0)
        : rt.progress;
    if (p == rt.progress) return;
    if (p >= 1.0 && rt.status == PlanStatus.active) {
      _runtimes['$planId|${occ.dateKey}'] = rt.copyWith(
        progress: 1,
        status: PlanStatus.completed,
        completedAt: now,
      );
      _saveRuntimes();
      _archiveIfFinal(occ, now);
      _notifyTransition(occ, PlanStatus.active, PlanStatus.completed);
      return;
    }
    _runtimes['$planId|${occ.dateKey}'] = rt.copyWith(progress: p);
    _saveRuntimes();
    _refreshScheduling(now);
  }

  // ---- 状态机心跳(每秒由 ClockScreen._tick 驱动)----

  void onTick(DateTime now) {
    if (!_enabled || _plans.isEmpty) return;
    var changed = false;

    final today = startOfDay(now);
    final occurrences = occurrencesOnDay(_plans, today);

    for (final occ in occurrences) {
      final key = '${occ.plan.id}|${occ.dateKey}';
      var rt = _runtimes[key];

      // 未建实例:到点自动开始 / 已过结束则自动跳过(收敛)
      // 注意:若该实例已终结归档(完成/跳过),不再自动重新激活
      if (rt == null &&
          !now.isBefore(occ.scheduledStart) &&
          occ.plan.progressType == ProgressType.automatic &&
          !_isFinalized(occ) &&
          !_hasRunningBefore(occ, occurrences)) {
        final tmp = PlanRuntime(planId: occ.plan.id, dateKey: occ.dateKey);
        if (now.isBefore(effectiveEnd(occ, tmp, now))) {
          _runtimes[key] = tmp.copyWith(status: PlanStatus.active, startedAt: now);
          _notifyTransition(occ, PlanStatus.unstarted, PlanStatus.active);
        } else {
          _runtimes[key] = tmp.copyWith(status: PlanStatus.skipped);
          _notifyTransition(occ, PlanStatus.unstarted, PlanStatus.skipped);
        }
        changed = true;
        rt = _runtimes[key];
      }

      if (rt == null) {
        _maybeFireReminder(occ, now);
        continue;
      }

      switch (rt.status) {
        case PlanStatus.unstarted:
          if (!now.isBefore(occ.scheduledStart) &&
              occ.plan.progressType == ProgressType.automatic &&
              !_hasRunningBefore(occ, occurrences)) {
            _runtimes[key] = rt.copyWith(status: PlanStatus.active, startedAt: now);
            _notifyTransition(occ, PlanStatus.unstarted, PlanStatus.active);
            changed = true;
          }
          break;
        case PlanStatus.active:
          if (now.isAfter(effectiveEnd(occ, rt, now))) {
            _runtimes[key] = rt.copyWith(status: PlanStatus.overdue);
            _notifyTransition(occ, PlanStatus.active, PlanStatus.overdue);
            changed = true;
          }
          break;
        case PlanStatus.paused:
        case PlanStatus.overdue:
        case PlanStatus.completed:
        case PlanStatus.skipped:
          break;
      }

      _maybeFireReminder(occ, now);
    }

    // 自动顺延(不再弹窗):当前计划仍在进行(active/overdue)且已越过后续计划开始点
    // → 后续计划按当前实际结束逐级顺延,直到用户结束当前任务后续才自动开始
    PlanOccurrence? running;
    PlanRuntime? runningRt;
    for (final occ in occurrences) {
      if (occ.scheduledStart.isAfter(now)) break;
      final r = _runtimes['${occ.plan.id}|${occ.dateKey}'];
      if (r != null &&
          (r.status == PlanStatus.active || r.status == PlanStatus.overdue)) {
        running = occ;
        runningRt = r;
      }
    }
    if (running != null && runningRt != null) {
      // 只要当前仍在进行,后续计划持续顺延到其实际结束之后
      // (超时进行中则随 now 推进,当前超时多少后续顺延多少)
      cascadeDelay(running, runningRt, now);
    }

    changed = _archivePast(today, now) || changed;

    _tickCount++;
    if (_tickCount % 30 == 0) persistentTickCallback?.call(now);

    if (changed) {
      _saveRuntimes();
      _refreshScheduling(now);
      notifyListeners();
    }
  }

  /// 是否存在开始更早且仍进行中(active/overdue)的前序计划 → 压制当前计划,不应自动开始
  bool _hasRunningBefore(PlanOccurrence occ, List<PlanOccurrence> occurrences) {
    for (final o in occurrences) {
      if (o.scheduledStart.isBefore(occ.scheduledStart)) {
        final r = _runtimes['${o.plan.id}|${o.dateKey}'];
        if (r != null &&
            (r.status == PlanStatus.active || r.status == PlanStatus.overdue)) {
          return true;
        }
      }
    }
    return false;
  }

  void _maybeFireReminder(PlanOccurrence occ, DateTime now) {
    if (!occ.plan.notificationEnabled) return;
    final reminders = occ.plan.remindersMinBefore;
    if (reminders.isEmpty) return;
    if (!now.isBefore(occ.scheduledStart)) return; // 已开始不再提醒
    for (final min in reminders) {
      if (now.isBefore(occ.scheduledStart.subtract(Duration(minutes: min)))) {
        continue;
      }
      final fireKey = '${occ.plan.id}|${occ.dateKey}|$min';
      if (_firedReminders.add(fireKey)) {
        reminderCallback?.call(occ, min);
      }
    }
  }

  void _notifyTransition(
      PlanOccurrence occ, PlanStatus oldStatus, PlanStatus newStatus) {
    if (oldStatus == newStatus) return;
    onStatusChanged?.call(occ, oldStatus, newStatus);
    _refreshScheduling(DateTime.now());
  }

  // ---- 查询(供 UI)----

  /// 今日进行中的实例(active/paused/overdue),按开始时间取第一个
  PlanOccurrence? currentOccurrence(DateTime now) {
    if (!_enabled) return null;
    for (final o in occurrencesOnDay(_plans, now)) {
      final rt = _runtimes['${o.plan.id}|${o.dateKey}'];
      if (rt != null &&
          (rt.status == PlanStatus.active ||
              rt.status == PlanStatus.paused ||
              rt.status == PlanStatus.overdue)) {
        return o;
      }
    }
    return null;
  }

  PlanRuntime? runtimeFor(PlanOccurrence occ) =>
      _runtimes['${occ.plan.id}|${occ.dateKey}'];

  /// 今日所有实例
  List<PlanOccurrence> todayOccurrences(DateTime now) {
    if (!_enabled) return const [];
    return occurrencesOnDay(_plans, now);
  }

  /// 下一未开始计划的信息(名称 + 开始时间点),供常驻通知展示
  ({String title, DateTime start})? nextPlanInfo(DateTime now) {
    if (!_enabled) return null;
    final n = nextOccurrence(_plans, now);
    if (n == null) return null;
    return (title: n.plan.title, start: n.scheduledStart);
  }

  // ---- 内部 ----

  PlanOccurrence? _todayOccurrence(String planId, DateTime now) {
    for (final p in _plans) {
      if (p.id == planId) return occurrenceOn(p, now);
    }
    return null;
  }

  PlanRuntime? _runtimeOf(String planId, String dateKey) =>
      _runtimes['$planId|$dateKey'];

  /// 该计划某天实例是否已被终结归档(完成/跳过),避免自动重新激活
  bool _isFinalized(PlanOccurrence occ) => _history.any(
      (h) => h.planId == occ.plan.id && h.dateKey == occ.dateKey);

  /// 按 id 取当前计划(编辑保存基准用最新值,避免自动顺延导致的快照不一致)
  Plan? planById(String id) => _planById(id);

  Plan? _planById(String id) {
    for (final p in _plans) {
      if (p.id == id) return p;
    }
    return null;
  }

  PlanRuntime _ensureRuntime(String planId, String dateKey) =>
      _runtimes['$planId|$dateKey'] ??
      (_runtimes['$planId|$dateKey'] =
          PlanRuntime(planId: planId, dateKey: dateKey));

  /// 终结归档(完成/跳过):写入历史并移除 runtime
  void _archiveIfFinal(PlanOccurrence occ, DateTime now) {
    final rt = _runtimes['${occ.plan.id}|${occ.dateKey}'];
    if (rt == null) return;
    if (rt.status != PlanStatus.completed && rt.status != PlanStatus.skipped) {
      return;
    }
    final end = effectiveEnd(occ, rt, now);
    final started = rt.startedAt;
    final actualEnd = rt.completedAt ?? end;
    final active = started == null
        ? Duration.zero
        : actualEnd.difference(started) - rt.totalPausedDuration;
    _history = [
      ..._history,
      PlanHistoryRecord(
        planId: occ.plan.id,
        dateKey: occ.dateKey,
        title: occ.plan.title,
        scheduledStart: occ.scheduledStart,
        effectiveEnd: end,
        finalStatus: rt.status,
        plannedDuration: occ.plan.duration,
        actualActive: active.isNegative ? Duration.zero : active,
        interruptionCount: rt.pauseHistory.length + rt.adjustments.length,
        completedAt: rt.completedAt,
        actualStart: started,
        actualEnd: actualEnd,
      ),
    ];
    if (_history.length > 2000) {
      _history = _history.sublist(_history.length - 2000);
    }
    _saveHistory();
    _runtimes.remove('${occ.plan.id}|${occ.dateKey}');
    _saveRuntimes();
  }

  /// 归档过期(昨天及更早)的 runtime
  bool _archivePast(DateTime today, DateTime now) {
    var changed = false;
    final keys = _runtimes.keys.toList();
    for (final key in keys) {
      final sep = key.indexOf('|');
      final dateKey = key.substring(sep + 1);
      if (dateKey.compareTo(formatDateKey(today)) >= 0) continue;
      final rt = _runtimes[key]!;
      final plan = _planById(rt.planId);
      final day = parseDateKey(dateKey);
      final occ = plan == null ? null : occurrenceOn(plan, day);
      if (occ != null) {
        final end = effectiveEnd(occ, rt, now);
        final started = rt.startedAt;
        final actualEnd = rt.completedAt ?? end;
        final active = started == null
            ? Duration.zero
            : actualEnd.difference(started) - rt.totalPausedDuration;
        final finalStatus = switch (rt.status) {
          PlanStatus.completed => PlanStatus.completed,
          PlanStatus.skipped => PlanStatus.skipped,
          _ => rt.status == PlanStatus.active || rt.status == PlanStatus.paused
              ? PlanStatus.overdue
              : rt.status,
        };
        _history = [
          ..._history,
          PlanHistoryRecord(
            planId: rt.planId,
            dateKey: dateKey,
            title: occ.plan.title,
            scheduledStart: occ.scheduledStart,
            effectiveEnd: end,
            finalStatus: finalStatus,
            plannedDuration: occ.plan.duration,
            actualActive: active.isNegative ? Duration.zero : active,
            interruptionCount:
                rt.pauseHistory.length + rt.adjustments.length,
            completedAt: rt.completedAt,
            actualStart: started,
            actualEnd: actualEnd,
          ),
        ];
      }
      _runtimes.remove(key);
      changed = true;
    }
    if (changed) _saveHistory();
    return changed;
  }

  /// 加时后与后续计划的冲突提示
  List<String> _overlapWarnings(
      String planId, PlanOccurrence occ, int deltaMinutes, DateTime now) {
    final rt = _runtimes['$planId|${occ.dateKey}']!;
    final newEnd = effectiveEnd(occ, rt, now);
    final later = todayOccurrences(now)
        .where((e) =>
            e.plan.id != planId &&
            e.scheduledStart.isAfter(occ.scheduledStart) &&
            e.scheduledStart.isBefore(newEnd))
        .toList();
    return [
      for (final e in later)
        '「${e.plan.title}」将被「${occ.plan.title}」加时覆盖(开始 ${_hhmm(e.scheduledStart)})',
    ];
  }

  String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  /// 状态迁移/计划变更后刷新闹钟调度与常驻通知
  void _refreshScheduling(DateTime now) {
    schedulingCallback?.call();
    persistentTickCallback?.call(now);
  }

  /// 启动时对账:active 但已超结束 → overdue;unstarted 且已过 → skipped
  void _reconcileOnLoad(DateTime now) {
    var changed = false;
    final today = startOfDay(now);
    final keys = _runtimes.keys.toList();
    for (final key in keys) {
      final rt = _runtimes[key]!;
      final plan = _planById(rt.planId);
      if (plan == null) {
        _runtimes.remove(key);
        changed = true;
        continue;
      }
      final occ = occurrenceOn(plan, parseDateKey(rt.dateKey));
      if (occ == null) continue;
      final end = effectiveEnd(occ, rt, now);
      switch (rt.status) {
        case PlanStatus.active:
          if (now.isAfter(end)) {
            _runtimes[key] = rt.copyWith(status: PlanStatus.overdue);
            changed = true;
          }
          break;
        case PlanStatus.unstarted:
          if (now.isAfter(occ.scheduledEnd)) {
            _runtimes[key] = rt.copyWith(status: PlanStatus.skipped);
            changed = true;
          }
          break;
        default:
          break;
      }
    }
    if (_archivePast(today, now)) changed = true;
    if (changed) _saveRuntimes();
  }

  // ---- 持久化 ----
  void _savePlans() {
    _prefs.setStringList(
        _kPlans, _plans.map((p) => jsonEncode(p.toJson())).toList());
  }

  void _saveRuntimes() {
    _prefs.setStringList(
        _kRuntimes, _runtimes.values.map((r) => jsonEncode(r.toJson())).toList());
  }

  void _saveHistory() {
    _prefs.setStringList(
        _kHistory, _history.map((h) => jsonEncode(h.toJson())).toList());
  }
}

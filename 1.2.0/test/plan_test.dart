import 'package:flutter_test/flutter_test.dart';
import 'package:fullscreen_clock/models/plan.dart';
import 'package:fullscreen_clock/models/plan_conflict.dart';
import 'package:fullscreen_clock/models/plan_repeat.dart';
import 'package:fullscreen_clock/providers/plan_provider.dart';
import 'package:fullscreen_clock/utils/plan_json.dart';
import 'package:fullscreen_clock/utils/plan_time.dart';
import 'package:shared_preferences/shared_preferences.dart';

Plan makePlan(
  String id, {
  required DateTime start,
  Duration dur = const Duration(minutes: 30),
  RepeatRule repeat = const RepeatRule(),
  ProgressType progressType = ProgressType.automatic,
}) {
  return Plan(id: id, title: '计划$id', startDate: start, duration: dur, repeat: repeat, progressType: progressType);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<PlanProvider> newProvider() async {
    SharedPreferences.setMockInitialValues({});
    return PlanProvider(await SharedPreferences.getInstance());
  }

  group('重复展开', () {
    test('每天', () async {
      final p = makePlan('d', start: DateTime(2026, 8, 15, 9), repeat: const RepeatRule(frequency: PlanRepeatFrequency.daily));
      expect(occurrenceOn(p, DateTime(2026, 8, 15)), isNotNull);
      expect(occurrenceOn(p, DateTime(2026, 8, 16)), isNotNull);
      expect(occurrenceOn(p, DateTime(2026, 8, 14)), isNull);
    });

    test('每周(一、三)', () async {
      // 2026-08-15 是周六。锚点取一个周一:2026-08-10
      final p = makePlan('w', start: DateTime(2026, 8, 10, 9), repeat: const RepeatRule(frequency: PlanRepeatFrequency.weekly, daysOfWeek: [1, 3]));
      expect(occurrenceOn(p, DateTime(2026, 8, 10)), isNotNull); // 周一
      expect(occurrenceOn(p, DateTime(2026, 8, 12)), isNotNull); // 周三
      expect(occurrenceOn(p, DateTime(2026, 8, 11)), isNull); // 周二
    });

    test('工作日', () async {
      final p = makePlan('wd', start: DateTime(2026, 8, 10, 9), repeat: const RepeatRule(frequency: PlanRepeatFrequency.workdays));
      expect(occurrenceOn(p, DateTime(2026, 8, 14)), isNotNull); // 周五
      expect(occurrenceOn(p, DateTime(2026, 8, 15)), isNull); // 周六
    });

    test('每月(1、15 日)', () async {
      final p = makePlan('m', start: DateTime(2026, 8, 1, 9), repeat: const RepeatRule(frequency: PlanRepeatFrequency.monthly, daysOfMonth: [1, 15]));
      expect(occurrenceOn(p, DateTime(2026, 8, 1)), isNotNull);
      expect(occurrenceOn(p, DateTime(2026, 8, 15)), isNotNull);
      expect(occurrenceOn(p, DateTime(2026, 8, 10)), isNull);
    });

    test('结束条件:重复 N 次', () async {
      final p = makePlan('c', start: DateTime(2026, 8, 15, 9),
          repeat: const RepeatRule(frequency: PlanRepeatFrequency.daily, endType: RepeatEndCondition.count, repeatCount: 3));
      expect(occurrenceOn(p, DateTime(2026, 8, 15)), isNotNull);
      expect(occurrenceOn(p, DateTime(2026, 8, 17)), isNotNull); // 第 3 次
      expect(occurrenceOn(p, DateTime(2026, 8, 18)), isNull); // 第 4 次,超限
    });

    test('结束条件:持续到某天', () async {
      final p = makePlan('u', start: DateTime(2026, 8, 15, 9),
          repeat: RepeatRule(frequency: PlanRepeatFrequency.daily, endType: RepeatEndCondition.until, untilDate: DateTime(2026, 8, 17)));
      expect(occurrenceOn(p, DateTime(2026, 8, 17)), isNotNull);
      expect(occurrenceOn(p, DateTime(2026, 8, 18)), isNull);
    });

    test('下一计划倒计时', () async {
      final p1 = makePlan('a', start: DateTime(2026, 8, 15, 10));
      final p2 = makePlan('b', start: DateTime(2026, 8, 15, 14));
      final now = DateTime(2026, 8, 15, 12);
      final n = nextOccurrence([p1, p2], now);
      expect(n, isNotNull);
      expect(n!.plan.id, 'b');
    });
  });

  group('状态机', () {
    test('到点自动开始,结束转超时', () async {
      final provider = await newProvider();
      provider.setEnabled(true);
      provider.addPlan(makePlan('s1', start: DateTime(2026, 8, 15, 9)));
      // 开始前:不建 runtime
      provider.onTick(DateTime(2026, 8, 15, 8, 59));
      expect(provider.runtimes['s1|2026-08-15'], isNull);
      // 到点 → active
      provider.onTick(DateTime(2026, 8, 15, 9, 0));
      final rt = provider.runtimes['s1|2026-08-15'];
      expect(rt, isNotNull);
      expect(rt!.status, PlanStatus.active);
      // 结束时间已过 → overdue(不自动完成)
      provider.onTick(DateTime(2026, 8, 15, 9, 31));
      expect(provider.runtimes['s1|2026-08-15']!.status, PlanStatus.overdue);
    });

    test('暂停顺延:恢复后 effectiveEnd 延后相同长度', () async {
      final provider = await newProvider();
      provider.setEnabled(true);
      provider.addPlan(makePlan('p1', start: DateTime(2026, 8, 15, 9)));
      provider.start('p1', DateTime(2026, 8, 15, 9, 0));
      provider.pause('p1', DateTime(2026, 8, 15, 9, 10)); // 暂停 10 分钟
      provider.resume('p1', DateTime(2026, 8, 15, 9, 20)); // 恢复
      final occ = occurrenceOn(provider.plans.first, DateTime(2026, 8, 15))!;
      final rt = provider.runtimes['p1|2026-08-15']!;
      final end = effectiveEnd(occ, rt, DateTime(2026, 8, 15, 9, 20));
      // 原结束 9:30 + 暂停 10min → 9:40
      expect(end.hour, 9);
      expect(end.minute, 40);
      expect(rt.status, PlanStatus.active);
    });

    test('暂停期间不到点转超时', () async {
      final provider = await newProvider();
      provider.setEnabled(true);
      provider.addPlan(makePlan('p2', start: DateTime(2026, 8, 15, 9)));
      provider.start('p2', DateTime(2026, 8, 15, 9, 0));
      provider.pause('p2', DateTime(2026, 8, 15, 9, 5));
      // 暂停跨越原定结束时间
      provider.onTick(DateTime(2026, 8, 15, 9, 40));
      expect(provider.runtimes['p2|2026-08-15']!.status, PlanStatus.paused);
    });

    test('减时不允许低于已消耗,减到结束时间自动完成', () async {
      final provider = await newProvider();
      provider.setEnabled(true);
      provider.addPlan(makePlan('sh', start: DateTime(2026, 8, 15, 9)));
      provider.start('sh', DateTime(2026, 8, 15, 9, 0));
      // now=9:20,remaining=10min;减 25 → clamp 10 → 结束=now → 自动完成
      provider.shorten('sh', 25, DateTime(2026, 8, 15, 9, 20));
      expect(provider.history.last.finalStatus, PlanStatus.completed);
      expect(provider.runtimes['sh|2026-08-15'], isNull);
    });

    test('加时仅延长当前计划,并提示与后续计划重叠', () async {
      final provider = await newProvider();
      provider.setEnabled(true);
      provider.addPlan(makePlan('a', start: DateTime(2026, 8, 15, 9)));
      provider.addPlan(makePlan('b', start: DateTime(2026, 8, 15, 9, 30)));
      provider.start('a', DateTime(2026, 8, 15, 9, 0));
      final msgs = provider.extend('a', 20, DateTime(2026, 8, 15, 9, 20));
      expect(msgs, isNotEmpty); // 覆盖到 b 的开始时间
      // b 的时间未被移动
      final bOcc = occurrenceOn(
          provider.plans.firstWhere((p) => p.id == 'b'), DateTime(2026, 8, 15))!;
      expect(bOcc.scheduledStart.hour, 9);
      expect(bOcc.scheduledStart.minute, 30);
    });

    test('完成后写入历史', () async {
      final provider = await newProvider();
      provider.setEnabled(true);
      provider.addPlan(makePlan('h1', start: DateTime(2026, 8, 15, 9)));
      provider.start('h1', DateTime(2026, 8, 15, 9, 0));
      provider.complete('h1', DateTime(2026, 8, 15, 9, 30));
      expect(provider.history, hasLength(1));
      expect(provider.history.first.finalStatus, PlanStatus.completed);
      // runtime 已归档移除
      expect(provider.runtimes['h1|2026-08-15'], isNull);
    });

    test('movePlan:提前/延后整体平移开始与结束时间', () async {
      final provider = await newProvider();
      provider.setEnabled(true);
      provider.addPlan(makePlan('mv', start: DateTime(2026, 8, 15, 10)));
      provider.movePlan('mv', const Duration(minutes: -120));
      expect(provider.plans.first.startDate.hour, 8); // 提前 2 小时
      provider.movePlan('mv', const Duration(minutes: 90));
      expect(provider.plans.first.startDate.hour, 9); // 再延后 1.5 小时
    });

    test('movePlan:提前/延后到与前计划重叠被拒绝', () async {
      final provider = await newProvider();
      provider.setEnabled(true);
      provider.addPlan(makePlan('a', start: DateTime(2026, 8, 16, 10, 0)));
      provider.addPlan(makePlan('b', start: DateTime(2026, 8, 16, 11, 0)));
      // b 提前 31 分钟 → 10:29-10:59,与 a(10:00-10:30)重叠 → 拒绝
      final err = provider.movePlan('b', const Duration(minutes: -31));
      expect(err, isNotNull);
      // b 未被移动
      expect(provider.plans.firstWhere((p) => p.id == 'b').startDate.hour, 11);
      // 提前 30 分钟 → 10:30-11:00,背靠背不重叠 → 允许
      final ok = provider.movePlan('b', const Duration(minutes: -30));
      expect(ok, isNull);
      expect(provider.plans.firstWhere((p) => p.id == 'b').startDate.minute, 30);
    });

    test('undoLast:撤销加时恢复上一步调整', () async {
      final provider = await newProvider();
      provider.setEnabled(true);
      provider.addPlan(makePlan('u1', start: DateTime(2026, 8, 15, 9)));
      provider.start('u1', DateTime(2026, 8, 15, 9, 0));
      provider.extend('u1', 15, DateTime(2026, 8, 15, 9, 5));
      expect(provider.canUndo('u1'), isTrue);
      provider.undoLast('u1', DateTime(2026, 8, 15, 9, 6));
      final rt = provider.runtimes['u1|2026-08-15']!;
      expect(rt.adjustmentMinutes, 0); // 撤销后加时被还原
    });

    test('undoLast:完成后撤销恢复 runtime 并移除历史', () async {
      final provider = await newProvider();
      provider.setEnabled(true);
      provider.addPlan(makePlan('u2', start: DateTime(2026, 8, 15, 9)));
      provider.start('u2', DateTime(2026, 8, 15, 9, 0));
      provider.complete('u2', DateTime(2026, 8, 15, 9, 30));
      expect(provider.history, hasLength(1));
      provider.undoLast('u2', DateTime(2026, 8, 15, 9, 31));
      expect(provider.history, isEmpty);
      expect(provider.runtimes['u2|2026-08-15']!.status, PlanStatus.active);
    });

    test('ProgressType.none 时 setProgress 不改进度', () async {
      final provider = await newProvider();
      provider.setEnabled(true);
      provider.addPlan(makePlan('np', start: DateTime(2026, 8, 15, 9),
          progressType: ProgressType.none));
      provider.setProgress('np', 0.5, DateTime(2026, 8, 15, 9, 1));
      final rt = provider.runtimes['np|2026-08-15']!;
      expect(rt.progress, 0);
    });

    test('continueAndExtend:超时后继续并加时回到 active', () async {
      final provider = await newProvider();
      provider.setEnabled(true);
      provider.addPlan(makePlan('c1', start: DateTime(2026, 8, 15, 9)));
      provider.start('c1', DateTime(2026, 8, 15, 9, 0));
      provider.onTick(DateTime(2026, 8, 15, 9, 31)); // → overdue
      expect(provider.runtimes['c1|2026-08-15']!.status, PlanStatus.overdue);
      provider.continueAndExtend('c1', 10, DateTime(2026, 8, 15, 9, 31));
      final rt = provider.runtimes['c1|2026-08-15']!;
      expect(rt.status, PlanStatus.active);
      expect(rt.adjustments, hasLength(1));
    });
  });

  group('冲突检测', () {
    test('时间重叠为阻塞(不允许同时段有其他计划)', () {
      final occs = [
        PlanOccurrence(plan: makePlan('a', start: DateTime(2026, 8, 15, 9)), day: DateTime(2026, 8, 15), scheduledStart: DateTime(2026, 8, 15, 9), scheduledEnd: DateTime(2026, 8, 15, 9, 30)),
        PlanOccurrence(plan: makePlan('b', start: DateTime(2026, 8, 15, 9, 15)), day: DateTime(2026, 8, 15), scheduledStart: DateTime(2026, 8, 15, 9, 15), scheduledEnd: DateTime(2026, 8, 15, 9, 45)),
      ];
      final report = detectConflicts(occs);
      expect(report.issues.where((i) => i.type == ConflictType.overlap), hasLength(1));
      expect(report.hasBlocking, isTrue); // v1.1.1:同一时间段不允许有其他计划
    });

    test('模拟 _save:新建计划与已有计划重叠会被拦截', () {
      final existing = makePlan('a', start: DateTime(2026, 8, 16, 10, 0)); // 10:00-10:30
      final fresh = makePlan('b', start: DateTime(2026, 8, 16, 10, 10)); // 10:10-10:40 重叠
      final all = [...[existing], fresh];
      final report = detectConflicts(occurrencesOnDay(all, fresh.startDate));
      expect(report.hasBlocking, isTrue);
    });

    test('模拟 _save:新建完全同时计划被拦截', () {
      final existing = makePlan('a', start: DateTime(2026, 8, 16, 10, 0));
      final fresh = makePlan('b', start: DateTime(2026, 8, 16, 10, 0));
      final all = [...[existing], fresh];
      final report = detectConflicts(occurrencesOnDay(all, fresh.startDate));
      expect(report.hasBlocking, isTrue);
    });

    test('provider.addPlan:重叠计划被拒绝(兜底拦截)', () async {
      final provider = await newProvider();
      provider.setEnabled(true);
      provider.addPlan(makePlan('a', start: DateTime(2026, 8, 16, 10, 0)));
      final err =
          provider.addPlan(makePlan('b', start: DateTime(2026, 8, 16, 10, 10)));
      expect(err, isNotNull);
      expect(provider.plans, hasLength(1)); // B 未被添加
    });

    test('结束不晚于开始为阻塞', () {
      final occs = [
        PlanOccurrence(plan: makePlan('a', start: DateTime(2026, 8, 15, 9)), day: DateTime(2026, 8, 15), scheduledStart: DateTime(2026, 8, 15, 9, 30), scheduledEnd: DateTime(2026, 8, 15, 9, 0)),
      ];
      final report = detectConflicts(occs);
      expect(report.hasBlocking, isTrue);
      expect(report.issues.first.type, ConflictType.endBeforeStart);
    });
  });

  group('JSON', () {
    test('Plan JSON round-trip 保字段', () {
      final p = Plan(
        id: 'x1',
        title: '读书',
        notes: '第3章',
        color: 0xFF112233,
        iconName: 'book',
        tags: const ['学习'],
        startDate: DateTime(2026, 8, 15, 9, 30),
        duration: const Duration(minutes: 45),
        repeat: const RepeatRule(frequency: PlanRepeatFrequency.weekly, daysOfWeek: [1, 3, 5]),
        remindersMinBefore: const [5, 10],
        lockVisibility: LockScreenVisibility.private,
      );
      final back = Plan.fromJson(p.toJson());
      expect(back.id, p.id);
      expect(back.title, p.title);
      expect(back.notes, p.notes);
      expect(back.color, p.color);
      expect(back.iconName, p.iconName);
      expect(back.startDate, p.startDate);
      expect(back.duration, p.duration);
      expect(back.repeat.frequency, PlanRepeatFrequency.weekly);
      expect(back.repeat.daysOfWeek, [1, 3, 5]);
      expect(back.remindersMinBefore, [5, 10]);
      expect(back.lockVisibility, LockScreenVisibility.private);
    });

    test('导出/校验:合法数据无错误,缺失必填有错误', () {
      final root = buildExportJson([makePlan('e1', start: DateTime(2026, 8, 15, 9))], {}, DateTime(2026, 8, 15));
      final ok = validateImport(root);
      expect(ok.hasErrors, isFalse);

      final bad = validateImport({'schemaVersion': '1.0.0', 'plans': [{'id': 'e1', 'startDate': 'not-a-date'}]});
      expect(bad.hasErrors, isTrue);
    });

    test('parseIsoToLocal:带时区时间转本地,避免导入偏移8小时', () {
      // UTC 时间 → 转本地(isUtc=false)
      final utc = parseIsoToLocal('2026-08-20T10:00:00Z');
      expect(utc.isUtc, isFalse);
      // 带 +08:00 偏移 → 转本地
      final off = parseIsoToLocal('2026-08-20T10:00:00+08:00');
      expect(off.isUtc, isFalse);
      expect(off.hour, 10);
      // 无时区 → 保持本地原样
      final bare = parseIsoToLocal('2026-08-20T10:00:00');
      expect(bare.isUtc, isFalse);
      expect(bare.hour, 10);
    });
  });
}

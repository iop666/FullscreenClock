import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/plan.dart';
import '../models/plan_history.dart';
import '../providers/plan_provider.dart';
import '../services/plan_export_service.dart';
import '../theme/app_theme.dart';
import '../utils/plan_time.dart';

/// 统计与历史页:完成率、实际 vs 计划时长、中断次数、历史记录
class PlanStatsScreen extends StatelessWidget {
  const PlanStatsScreen({
    super.key,
    required this.planProvider,
    required this.palette,
  });

  final PlanProvider planProvider;
  final Palette palette;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: planProvider,
      builder: (context, _) {
        final history = planProvider.history;
        final now = DateTime.now();
        final todayKey = formatDateKey(now);
        final weekStart = now.subtract(const Duration(days: 6));

        final todayRecords =
            history.where((h) => h.dateKey == todayKey).toList();
        final weekRecords = history
            .where((h) {
              final d = parseDateKey(h.dateKey);
              return !d.isBefore(startOfDay(weekStart));
            })
            .toList();

        final todayRate = _rate(todayRecords);
        final weekRate = _rate(weekRecords);
        final todayDone = todayRecords
            .where((h) => h.finalStatus == PlanStatus.completed)
            .length;
        final weekDone = weekRecords
            .where((h) => h.finalStatus == PlanStatus.completed)
            .length;
        final (todayPlanned, todayActual) = _durations(todayRecords);
        final (weekPlanned, weekActual) = _durations(weekRecords);
        final interruptions =
            weekRecords.fold<int>(0, (s, h) => s + h.interruptionCount);

        return Scaffold(
          backgroundColor: palette.background,
          appBar: AppBar(
            backgroundColor: palette.background,
            foregroundColor: palette.foreground,
            elevation: 0,
            title: const Text('统计与历史'),
            actions: [
              IconButton(
                tooltip: '导出统计报告',
                onPressed: () => _exportReport(context, history),
                icon: Icon(Icons.download_outlined, color: palette.accent),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _row3(
                _card(palette, '今日完成率', todayRate, todayDone),
                _card(palette, '本周完成率', weekRate, weekDone),
              ),
              const SizedBox(height: 12),
              _card2([
                _statLine(palette, '今日计划时长', _fmtDuration(todayPlanned)),
                _statLine(palette, '今日实际投入', _fmtDuration(todayActual)),
                _statLine(palette, '本周计划时长', _fmtDuration(weekPlanned)),
                _statLine(palette, '本周实际投入', _fmtDuration(weekActual)),
                _statLine(palette, '中断次数', '$interruptions 次'),
              ]),
              const SizedBox(height: 20),
              Text('历史记录', style: _section(palette)),
              if (history.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      '暂无历史记录\n完成或跳过计划后自动归档',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: palette.secondary, fontSize: 14),
                    ),
                  ),
                )
              else
                for (final group in _groupByDay(history)) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 6),
                    child: Text(
                      group.key,
                      style: TextStyle(
                        color: palette.secondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  for (final h in group.value) _historyTile(h),
                ],
            ],
          ),
        );
      },
    );
  }

  // ---- 统计计算 ----

  double _rate(List<PlanHistoryRecord> records) {
    if (records.isEmpty) return 0;
    final completed =
        records.where((h) => h.finalStatus == PlanStatus.completed).length;
    return completed / records.length;
  }

  (Duration, Duration) _durations(List<PlanHistoryRecord> records) {
    var planned = Duration.zero;
    var actual = Duration.zero;
    for (final h in records) {
      planned += h.plannedDuration;
      actual += h.actualActive;
    }
    return (planned, actual);
  }

  List<MapEntry<String, List<PlanHistoryRecord>>> _groupByDay(
      List<PlanHistoryRecord> history) {
    final map = <String, List<PlanHistoryRecord>>{};
    for (final h in history) {
      map.putIfAbsent(h.dateKey, () => []).add(h);
    }
    final entries = map.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    return entries;
  }

  // ---- UI ----

  TextStyle _section(Palette p) => TextStyle(
        color: p.secondary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
      );

  Widget _card(Palette p, String label, double rate, int done) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(color: p.secondary, fontSize: 12)),
            const SizedBox(height: 6),
            Text(
              '${(rate * 100).round()}%',
              style: TextStyle(
                color: p.accent,
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
            LinearProgressIndicator(
              value: rate,
              minHeight: 5,
              backgroundColor: p.cardBorder,
              valueColor: AlwaysStoppedAnimation(p.accent),
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 4),
            Text('完成 $done 个',
                style: TextStyle(color: p.secondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _row3(Widget a, Widget b) => Row(
        children: [a, const SizedBox(width: 12), b],
      );

  Widget _card2(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(children: children),
    );
  }

  Widget _statLine(Palette p, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
              child:
                  Text(label, style: TextStyle(color: p.foreground, fontSize: 15))),
          Text(value,
              style: TextStyle(color: p.accent, fontSize: 15, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _historyTile(PlanHistoryRecord h) {
    final statusColor = switch (h.finalStatus) {
      PlanStatus.completed => const Color(0xFF1FAF58),
      PlanStatus.skipped => palette.secondary,
      PlanStatus.overdue => const Color(0xFFE53935),
      _ => palette.secondary,
    };
    final statusLabel = switch (h.finalStatus) {
      PlanStatus.completed => '完成',
      PlanStatus.skipped => '跳过',
      PlanStatus.overdue => '超时',
      _ => '未完成',
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 32,
            decoration: BoxDecoration(
                color: statusColor, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  h.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: palette.foreground,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
                Text(
                  _historySubtitle(h),
                  style: TextStyle(color: palette.secondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            statusLabel,
            style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  /// 历史记录副标题:显示计划/实际时长;已完成的显示实际完成时间点
  String _historySubtitle(PlanHistoryRecord h) {
    final base =
        '计划 ${_fmtDuration(h.plannedDuration)} · 实际 ${_fmtDuration(h.actualActive)}';
    if (h.finalStatus == PlanStatus.completed) {
      final t = h.actualEnd ?? h.completedAt;
      if (t != null) {
        return '$base\n${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
            '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} 完成';
      }
      return '$base\n已完成';
    }
    return base;
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes;
    if (m < 60) return '$m 分钟';
    return '${m ~/ 60}小时${m % 60}分';
  }

  Future<void> _exportReport(
      BuildContext context, List<PlanHistoryRecord> history) async {
    final d = DateTime.now();
    final report = {
      'exportedAt': d.toIso8601String(),
      'records': [for (final h in history) h.toJson()],
    };
    final path = await PlanExportService.saveTextToUserLocation(
      const JsonEncoder.withIndent('  ').convert(report),
      suggestedName:
          'fullscreen_clock_stats_${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}.json',
    );
    if (path == null) return;
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('统计报告已导出: $path')));
    }
  }
}

import 'package:flutter/material.dart';

import '../models/plan.dart';
import '../providers/plan_provider.dart';
import '../theme/app_theme.dart';
import '../utils/plan_time.dart';
import 'plan_progress_ring.dart';

/// 时钟页计划模块:当前计划卡 / 下一计划;支持位置/拆分/长按加/减时/撤销/超时/显示选项。
/// 位置与拆分布局由 ClockScreen 控制,本组件只负责内容。
class PlanOverlay extends StatelessWidget {
  const PlanOverlay({
    super.key,
    required this.planProvider,
    required this.palette,
    required this.now,
    this.onMessage,
  });

  final PlanProvider planProvider;
  final Palette palette;
  final DateTime now;
  final void Function(String message)? onMessage;

  @override
  Widget build(BuildContext context) {
    if (planProvider.moduleSplit) return _splitPanel(context);
    final occ = planProvider.currentOccurrence(now);
    if (occ != null) return _currentCard(context, occ);
    final next = planProvider.nextPlanInfo(now);
    if (next != null) return _nextBar(context, next);
    return const SizedBox.shrink();
  }

  /// 拆分模式:当前计划卡 + 后续计划列表 + 今日无计划提示
  Widget _splitPanel(BuildContext context) {
    final today = planProvider.todayOccurrences(now);
    final occ = planProvider.currentOccurrence(now);
    final children = <Widget>[];
    if (occ != null) {
      children.add(_currentCard(context, occ));
      children.add(const SizedBox(height: 8));
    }
    // 后续计划(显示到今日最后一个计划,已结束的不算)
    for (final u in today.where((o) {
      if (occ != null && o.plan.id == occ.plan.id && o.dateKey == occ.dateKey) {
        return false;
      }
      return !o.scheduledEnd.isBefore(now);
    })) {
      children.add(_upcomingCard(context, u));
      children.add(const SizedBox(height: 8));
    }
    if (children.isEmpty) {
      return Material(
        color: palette.card.withValues(alpha: 0.78),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: palette.cardBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('今日暂无计划',
              style: TextStyle(color: palette.secondary, fontSize: 14)),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  /// 拆分模式的后续计划卡片(只读)
  Widget _upcomingCard(BuildContext context, PlanOccurrence o) {
    final rt = planProvider.runtimeFor(o);
    final status = rt?.status ?? PlanStatus.unstarted;
    final statusColor = _statusColor(status);
    return Material(
      color: palette.card.withValues(alpha: 0.7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: palette.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.schedule, size: 15, color: palette.secondary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${o.plan.title} · ${_hhmm(o.scheduledStart)}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.foreground,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 6),
            _StatusChip(palette: palette, color: statusColor, label: _statusLabel(status)),
          ],
        ),
      ),
    );
  }

  // ---- 当前计划卡 ----

  Widget _currentCard(BuildContext context, PlanOccurrence occ) {
    final plan = occ.plan;
    final rt = planProvider.runtimeFor(occ) ??
        PlanRuntime(planId: plan.id, dateKey: occ.dateKey);
    final end = effectiveEnd(occ, rt, now);
    final status = rt.status;
    final scale = planProvider.overlayScale;

    final elapsed = rt.startedAt == null
        ? Duration.zero
        : now.difference(rt.startedAt!) - rt.totalPausedDuration;
    final remaining = end.difference(now).isNegative ? Duration.zero : end.difference(now);

    double progress = 0;
    if (plan.progressType == ProgressType.manual) {
      progress = rt.progress;
    } else if (plan.progressType == ProgressType.automatic) {
      final totalMs = end.difference(occ.scheduledStart).inMilliseconds;
      final elapsedMs = now.difference(occ.scheduledStart).inMilliseconds;
      progress = totalMs > 0 ? (elapsedMs / totalMs).clamp(0.0, 1.0) : 0.0;
    }

    final statusColor = _statusColor(status);
    // 超时时主时间显示「超时」,替换剩余时间
    final timeText = status == PlanStatus.overdue
        ? '超时 ${_fmtDuration(now.difference(end))}'
        : _timeText(planProvider.moduleTime, elapsed, remaining);

    return Material(
      color: palette.card.withValues(alpha: 0.88),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        // 进行中描边:可选默认色或计划颜色
        side: BorderSide(
          color: _active(status)
              ? (planProvider.moduleStrokePlanColor
                  ? Color(plan.color)
                  : palette.accent)
              : palette.cardBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 计划颜色条(默认关闭)
                if (planProvider.moduleShowColor) ...[
                  Container(
                    width: 5,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Color(plan.color),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (planProvider.moduleShowProgress)
                  PlanProgressRing(
                    progress: progress,
                    size: 44,
                    strokeWidth: 5,
                    color: statusColor,
                    trackColor: palette.cardBorder,
                    child: Text(
                      '${(progress * 100).round()}%',
                      style: TextStyle(
                        color: palette.foreground,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (planProvider.moduleShowProgress) const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (planProvider.moduleShowIcon) ...[
                            Icon(
                              plan.iconData,
                              size: 17 * scale,
                              // 图标颜色:开启「使用计划颜色」时用计划颜色
                              color: planProvider.moduleIconPlanColor
                                  ? Color(plan.color)
                                  : statusColor,
                            ),
                            const SizedBox(width: 5),
                          ],
                          Flexible(
                            child: Text(
                              plan.title,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.foreground,
                                fontSize: 20 * scale,
                                fontWeight: FontWeight.w600,
                                height: 1.15,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _StatusChip(
                              palette: palette,
                              color: statusColor,
                              label: _statusLabel(status)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        timeText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 13 * scale,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _actionsRow(context, occ, rt, status, scale),
          ],
        ),
      ),
    );
  }

  String _timeText(String mode, Duration elapsed, Duration remaining) {
    return switch (mode) {
      'elapsed' => '已执行 ${_fmtDuration(elapsed)}',
      // both:先同一行显示,空间不足时自动换行
      'both' =>
        '已执行 ${_fmtDuration(elapsed)} · 剩余 ${_fmtDuration(remaining)}',
      _ => '剩余 ${_fmtDuration(remaining)}',
    };
  }

  Widget _actionsRow(BuildContext context, PlanOccurrence occ, PlanRuntime rt,
      PlanStatus status, double scale) {
    final id = occ.plan.id;
    final now = this.now;
    final buttons = <Widget>[];
    switch (status) {
      case PlanStatus.active:
        buttons
          ..add(_ActionButton(palette: palette, scale: scale, icon: Icons.pause, label: '暂停',
              onTap: () => planProvider.pause(id, now)))
          ..add(_ActionButton(palette: palette, scale: scale, icon: Icons.remove, label: '减时',
              onTap: () => _shorten(context, occ, rt, 5),
              onLongPress: () => _askCustom(context, '减时(分钟)', (m) => _shorten(context, occ, rt, m))))
          ..add(_ActionButton(palette: palette, scale: scale, icon: Icons.add, label: '加时',
              onTap: () => planProvider.extend(id, 5, now),
              onLongPress: () => _askCustom(context, '加时(分钟)', (m) => planProvider.extend(id, m, now))))
          ..add(_ActionButton(palette: palette, scale: scale, icon: Icons.check, label: '完成',
              onTap: () => planProvider.complete(id, now)));
        break;
      case PlanStatus.paused:
        buttons
          ..add(_ActionButton(palette: palette, scale: scale, icon: Icons.play_arrow, label: '恢复',
              onTap: () => planProvider.resume(id, now)))
          ..add(_ActionButton(palette: palette, scale: scale, icon: Icons.remove, label: '减时',
              onTap: () => _shorten(context, occ, rt, 5),
              onLongPress: () => _askCustom(context, '减时(分钟)', (m) => _shorten(context, occ, rt, m))))
          ..add(_ActionButton(palette: palette, scale: scale, icon: Icons.add, label: '加时',
              onTap: () => planProvider.extend(id, 5, now),
              onLongPress: () => _askCustom(context, '加时(分钟)', (m) => planProvider.extend(id, m, now))))
          ..add(_ActionButton(palette: palette, scale: scale, icon: Icons.check, label: '完成',
              onTap: () => planProvider.complete(id, now)));
        break;
      case PlanStatus.overdue:
        buttons
          ..add(_ActionButton(palette: palette, scale: scale, icon: Icons.close, label: '放弃',
              onTap: () => planProvider.abandon(id, now)))
          ..add(_ActionButton(palette: palette, scale: scale, icon: Icons.add, label: '继续+5',
              onTap: () => planProvider.continueAndExtend(id, 5, now)))
          ..add(_ActionButton(palette: palette, scale: scale, icon: Icons.check, label: '完成',
              onTap: () => planProvider.complete(id, now)));
        break;
      default:
        break;
    }
    if (planProvider.canUndo(id)) {
      buttons.add(_ActionButton(palette: palette, scale: scale, icon: Icons.undo, label: '撤销',
          onTap: () => _undo(context, id)));
    }
    return Wrap(spacing: 8, runSpacing: 8, children: buttons);
  }

  /// 减时:若减时超过剩余时间,弹确认;确认后执行(自动标记完成)
  void _shorten(BuildContext context, PlanOccurrence occ, PlanRuntime rt, int delta) {
    final end = effectiveEnd(occ, rt, now);
    final remainingSec = end.difference(now).inSeconds;
    if (delta * 60 > remainingSec) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: palette.card,
          title: Text('确认减时',
              style: TextStyle(color: palette.foreground)),
          content: Text(
            '减时 $delta 分钟将超过剩余时间,完成后该任务将列为完成。确认?',
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
                final msgs = planProvider.shorten(occ.plan.id, delta, now);
                if (msgs.isNotEmpty) onMessage?.call(msgs.join('\n'));
              },
              child: Text('确认', style: TextStyle(color: palette.accent)),
            ),
          ],
        ),
      );
      return;
    }
    final msgs = planProvider.shorten(occ.plan.id, delta, now);
    if (msgs.isNotEmpty) onMessage?.call(msgs.join('\n'));
  }

  void _undo(BuildContext context, String id) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.card,
        title: Text('撤销操作',
            style: TextStyle(color: palette.foreground)),
        content: Text('确定撤销该计划的上一步操作吗?',
            style: TextStyle(color: palette.foreground)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('取消', style: TextStyle(color: palette.secondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              planProvider.undoLast(id, now);
            },
            child: Text('撤销', style: TextStyle(color: palette.accent)),
          ),
        ],
      ),
    );
  }

  Future<void> _askCustom(BuildContext context, String title, void Function(int) apply) async {
    final controller = TextEditingController();
    final minutes = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.card,
        title: Text(title, style: TextStyle(color: palette.foreground, fontSize: 17)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: TextStyle(color: palette.foreground, fontSize: 16),
          decoration: const InputDecoration(hintText: '请输入分钟数'),
          onSubmitted: (t) {
            final n = int.tryParse(t);
            if (n != null && n > 0) Navigator.of(ctx).pop(n);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('取消', style: TextStyle(color: palette.secondary)),
          ),
          TextButton(
            onPressed: () {
              final n = int.tryParse(controller.text);
              if (n != null && n > 0) Navigator.of(ctx).pop(n);
            },
            child: Text('确定', style: TextStyle(color: palette.accent)),
          ),
        ],
      ),
    );
    if (minutes != null && minutes > 0) apply(minutes);
  }

  // ---- 下一计划 ----

  Widget _nextBar(BuildContext context, ({String title, DateTime start}) next) {
    final scale = planProvider.overlayScale;
    return Material(
      color: palette.card.withValues(alpha: 0.78),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: palette.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule, color: palette.accent, size: 18 * scale),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '下一计划: ${next.title} · 开始 ${_hhmm(next.start)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.foreground,
                  fontSize: 14 * scale,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- 辅助 ----

  bool _active(PlanStatus s) => s == PlanStatus.active;

  Color _statusColor(PlanStatus s) => switch (s) {
        PlanStatus.active => palette.accent,
        PlanStatus.paused => const Color(0xFFFFB300),
        PlanStatus.overdue => const Color(0xFFE53935),
        PlanStatus.completed => const Color(0xFF1FAF58),
        PlanStatus.skipped => palette.secondary,
        PlanStatus.unstarted => palette.secondary,
      };

  String _statusLabel(PlanStatus s) => switch (s) {
        PlanStatus.active => '进行中',
        PlanStatus.paused => '已暂停',
        PlanStatus.overdue => '已超时',
        PlanStatus.completed => '已完成',
        PlanStatus.skipped => '已跳过',
        PlanStatus.unstarted => '未开始',
      };

  String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.palette, required this.color, required this.label});

  final Palette palette;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.palette,
    required this.scale,
    required this.icon,
    required this.label,
    required this.onTap,
    this.onLongPress,
  });

  final Palette palette;
  final double scale;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.background.withValues(alpha: 0.6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: palette.cardBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 7 * scale),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16 * scale, color: palette.foreground),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: palette.foreground,
                  fontSize: 13 * scale,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

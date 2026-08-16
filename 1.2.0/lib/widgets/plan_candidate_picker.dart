import 'package:flutter/material.dart';

import '../models/plan_candidate.dart';
import '../providers/plan_provider.dart';
import '../theme/app_theme.dart';

/// 计划编辑页的候选清单选择器:文件管理器式逐级浏览
/// 类型(一级)→ 主题(二级)→ 单元(三级)→ 标题(四级,点击选中)。
class PlanCandidatePicker extends StatefulWidget {
  const PlanCandidatePicker({
    super.key,
    required this.planProvider,
    required this.palette,
    required this.onPicked,
  });

  final PlanProvider planProvider;
  final Palette palette;
  final ValueChanged<PlanCandidate> onPicked;

  @override
  State<PlanCandidatePicker> createState() => _PlanCandidatePickerState();
}

class _PlanCandidatePickerState extends State<PlanCandidatePicker> {
  /// 当前层级路径:[类型, 主题, 单元];长度为 0=类型层,3=标题层
  List<String> _path = [];

  PlanProvider get planProvider => widget.planProvider;
  Palette get palette => widget.palette;
  int get _level => _path.length;

  /// 当前层级下的下一级唯一值(文件夹:类型/主题/单元;文件:标题)
  List<String> _children() {
    final set = <String>{};
    for (final c in planProvider.candidates) {
      if (_path.isNotEmpty && c.type != _path[0]) continue;
      if (_path.length >= 2 && c.topic != _path[1]) continue;
      if (_path.length >= 3 && c.unit != _path[2]) continue;
      switch (_level) {
        case 0:
          if (c.type.trim().isNotEmpty) set.add(c.type.trim());
        case 1:
          if (c.topic.trim().isNotEmpty) set.add(c.topic.trim());
        case 2:
          if (c.unit.trim().isNotEmpty) set.add(c.unit.trim());
        case 3:
          if (c.title.trim().isNotEmpty) set.add(c.title.trim());
      }
    }
    return set.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: planProvider,
      builder: (context, _) {
        final items = _children();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Text(
                    '选择候选',
                    style: TextStyle(
                        color: palette.foreground,
                        fontSize: 16,
                        fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: palette.secondary),
                  ),
                ],
              ),
            ),
            // 面包屑目录路径(点击某段回到该段之前层级)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _crumbs(),
              ),
            ),
            const SizedBox(height: 4),
            Divider(height: 1, color: palette.cardBorder),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        _path.isEmpty ? '候选清单为空' : '当前层级为空',
                        style: TextStyle(
                            color: palette.secondary, fontSize: 15),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                      itemCount: items.length,
                      itemBuilder: (context, i) => _row(items[i]),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _crumbs() {
    return Row(
      children: [
        InkWell(
          onTap: () => setState(() => _path.clear()),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Icon(Icons.folder, size: 18, color: palette.accent),
          ),
        ),
        for (var i = 0; i < _path.length; i++) ...[
          Icon(Icons.chevron_right, size: 16, color: palette.secondary),
          InkWell(
            onTap: () => setState(() => _path = _path.sublist(0, i)),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(
                _path[i],
                style: TextStyle(
                    color: i == _path.length - 1
                        ? palette.foreground
                        : palette.accent,
                    fontSize: 14,
                    fontWeight: i == _path.length - 1
                        ? FontWeight.w700
                        : FontWeight.w500),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _row(String name) {
    final isFile = _level == 3;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        if (isFile) {
          // 标题(叶子):选中并回传
          widget.onPicked(PlanCandidate(
            type: _path.isNotEmpty ? _path[0] : '',
            topic: _path.length > 1 ? _path[1] : '',
            unit: _path.length > 2 ? _path[2] : '',
            title: name,
          ));
        } else {
          setState(() => _path = [..._path, name]);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              isFile ? Icons.description_outlined : Icons.folder,
              color: isFile ? palette.secondary : palette.accent,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.foreground,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              isFile ? Icons.check_circle_outline : Icons.chevron_right,
              color: isFile ? palette.accent : palette.secondary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

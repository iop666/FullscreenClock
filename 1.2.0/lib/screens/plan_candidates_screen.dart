import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/plan_candidate.dart';
import '../providers/plan_provider.dart';
import '../services/plan_export_service.dart';
import '../theme/app_theme.dart';

/// 候选清单(文件管理器式):层级浏览 类型→主题→单元→标题。
/// 顶部面包屑路径(点击回到上级)、当前层级下逐级进入、按层级添加。
class PlanCandidatesScreen extends StatefulWidget {
  const PlanCandidatesScreen({
    super.key,
    required this.planProvider,
    required this.palette,
  });

  final PlanProvider planProvider;
  final Palette palette;

  @override
  State<PlanCandidatesScreen> createState() => _PlanCandidatesScreenState();
}

class _PlanCandidatesScreenState extends State<PlanCandidatesScreen> {
  /// 当前层级路径:[类型, 主题, 单元];长度为 0=类型层,3=标题层
  List<String> _path = [];
  String _q = '';

  PlanProvider get planProvider => widget.planProvider;
  Palette get palette => widget.palette;

  int get _level => _path.length;

  /// 当前层级下的下一级唯一值(文件夹:类型/主题/单元;文件:标题)
  List<String> _children() {
    final set = <String>{};
    final q = _q.trim().toLowerCase();
    for (final c in planProvider.candidates) {
      if (_path.isNotEmpty && c.type != _path[0]) continue;
      if (_path.length >= 2 && c.topic != _path[1]) continue;
      if (_path.length >= 3 && c.unit != _path[2]) continue;
      if (q.isNotEmpty &&
          !(c.type + c.topic + c.unit + c.title).toLowerCase().contains(q)) {
        continue;
      }
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

  String get _crumbPath => _path.join(r'\');

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: planProvider,
      builder: (context, _) {
        final items = _children();
        return Scaffold(
          backgroundColor: palette.background,
          appBar: AppBar(
            backgroundColor: palette.background,
            foregroundColor: palette.foreground,
            elevation: 0,
            title: Text('候选清单',
                style: TextStyle(color: palette.foreground)),
            actions: [
              IconButton(
                tooltip: '添加候选',
                onPressed: _add,
                icon: Icon(Icons.add_circle_outline,
                    color: palette.accent),
              ),
              PopupMenuButton<String>(
                color: palette.card,
                onSelected: (v) {
                  if (v == 'paste') _pasteImport();
                  if (v == 'import') _import();
                  if (v == 'export') _export();
                  if (v == 'clear') _clearAll();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'paste',
                    child: Text('粘贴导入(AI 结构清单)',
                        style: TextStyle(color: palette.foreground)),
                  ),
                  PopupMenuItem(
                    value: 'import',
                    child: Text('导入结构清单',
                        style: TextStyle(color: palette.foreground)),
                  ),
                  PopupMenuItem(
                    value: 'export',
                    child: Text('导出结构清单',
                        style: TextStyle(color: palette.foreground)),
                  ),
                  PopupMenuItem(
                    value: 'clear',
                    child: Text('清空全部',
                        style:
                            TextStyle(color: const Color(0xFFE53935))),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              // 面包屑目录路径
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _crumbs(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
                child: TextField(
                  style: TextStyle(color: palette.foreground),
                  decoration: InputDecoration(
                    hintText: '搜索当前层级',
                    hintStyle: TextStyle(color: palette.secondary),
                    prefixIcon:
                        Icon(Icons.search, color: palette.secondary),
                    isDense: true,
                    filled: true,
                    fillColor: palette.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: palette.cardBorder),
                    ),
                  ),
                  onChanged: (v) => setState(() => _q = v),
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Text('当前层级为空\n点击右上角「添加候选」新建',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: palette.secondary, fontSize: 15)),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: items.length,
                        itemBuilder: (context, i) =>
                            _row(items[i]),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 面包屑:如 学习 \ AI \ agent(点击某段回到该段之前层级)
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
          // 标题(叶子):显示完整路径
          final path = '$_crumbPath\\$name';
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(path)));
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
            if (isFile)
              IconButton(
                tooltip: '删除',
                onPressed: () => _confirmDeleteLeaf(name),
                icon: Icon(Icons.delete_outline,
                    color: const Color(0xFFE53935), size: 20),
              )
            else
              Icon(Icons.chevron_right,
                  color: palette.secondary, size: 18),
          ],
        ),
      ),
    );
  }

  /// 删除标题(叶子)下的候选条目
  Future<void> _confirmDeleteLeaf(String title) async {
    final key = PlanCandidate(
      type: _path.isNotEmpty ? _path[0] : '',
      topic: _path.length > 1 ? _path[1] : '',
      unit: _path.length > 2 ? _path[2] : '',
      title: title,
    ).key;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.card,
        title: Text('删除候选',
            style: TextStyle(color: palette.foreground)),
        content: Text('确定删除「$title」吗?',
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
    if (ok == true) planProvider.removeCandidate(key);
  }

  /// 按当前层级添加:类型层只填类型,主题层只填主题,依此类推
  Future<void> _add() async {
    final label = switch (_level) {
      0 => '计划类型(一级)',
      1 => '计划主题(二级)',
      2 => '计划单元(三级)',
      _ => '标题(四级)',
    };
    final ctrl = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.card,
        title: Text('添加$label',
            style: TextStyle(color: palette.foreground)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: palette.foreground, fontSize: 15),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: palette.secondary, fontSize: 13),
            isDense: true,
            filled: true,
            fillColor: palette.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onSubmitted: (t) {
            if (t.trim().isNotEmpty) Navigator.of(ctx).pop(true);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('取消', style: TextStyle(color: palette.secondary)),
          ),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) Navigator.of(ctx).pop(true);
            },
            child: Text('添加', style: TextStyle(color: palette.accent)),
          ),
        ],
      ),
    );
    if (saved == true && ctrl.text.trim().isNotEmpty) {
      planProvider.addCandidate(PlanCandidate(
        type: _path.isNotEmpty ? _path[0] : ctrl.text.trim(),
        topic: _level >= 1
            ? (_level == 1 ? ctrl.text.trim() : _path[1])
            : '',
        unit: _level >= 2
            ? (_level == 2 ? ctrl.text.trim() : _path[2])
            : '',
        title: _level >= 3 ? ctrl.text.trim() : '',
      ));
    }
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.card,
        title: Text('清空全部',
            style: TextStyle(color: palette.foreground)),
        content: Text('确定清空所有候选条目吗?',
            style: TextStyle(color: palette.foreground)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('取消', style: TextStyle(color: palette.secondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('清空',
                style: TextStyle(color: Color(0xFFE53935))),
          ),
        ],
      ),
    );
    if (ok == true) planProvider.clearCandidates();
  }

  /// 粘贴导入:读剪贴板中的 AI 结构清单 JSON
  Future<void> _pasteImport() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text;
    if (text == null || text.trim().isEmpty) {
      _toast('剪贴板为空,请先复制结构清单 JSON');
      return;
    }
    final err = planProvider.importCandidatesContent(text.trim());
    _toast(err ?? '粘贴导入完成');
  }

  Future<void> _import() async {
    final picked = await PlanExportService.pickJsonFile();
    if (picked == null || !mounted) return;
    final err = planProvider.importCandidatesContent(picked.content);
    _toast(err ?? '导入完成');
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _export() async {
    final content = planProvider.exportCandidatesContent();
    final path = await PlanExportService.saveTextToUserLocation(
        content, suggestedName: 'plan_candidates.json');
    if (path != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('已导出: $path')));
    }
  }
}

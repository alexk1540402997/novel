import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/services/inspiration_service.dart';
import '../../domain/services/chapter_outline_service.dart';
import '../pages/novel_architecture_page.dart';

class OutlineNode {
  String title, content;
  List<OutlineNode> children;
  OutlineNode({this.title = '', this.content = '', this.children = const []});
  factory OutlineNode.fromJson(Map<String, dynamic> json) => OutlineNode(
    title: json['title'] ?? '', content: json['content'] ?? '',
    children: (json['children'] as List<dynamic>?)?.map((e) => OutlineNode.fromJson(e)).toList() ?? [],
  );
  Map<String, dynamic> toJson() => {'title': title, 'content': content, 'children': children.map((e) => e.toJson()).toList()};
}

enum _OutlineLevel { root, volume, chapter, leaf }

class OutlinePage extends StatefulWidget {
  const OutlinePage({super.key});
  @override State<OutlinePage> createState() => _OutlinePageState();
}

class _OutlinePageState extends State<OutlinePage> {
  String? _novel; OutlineNode? _root; String? _selectedPath;
  final _titleCtrl = TextEditingController(), _contentCtrl = TextEditingController();
  bool _autoSavePending = false;
  final Set<String> _collapsedPaths = {};

  @override void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) => _check()); }

  void _check() {
    final n = context.read<SelectedNovelProvider>().selectedNovel;
    if (n != _novel) { _novel = n; if (n != null) _load(); }
  }

  Future<void> _load() async {
    try {
      final svc = ChapterOutlineService();
      final data = await svc.loadOutline(_novel!);
      setState(() { _root = _fromMap(data); _selectedPath = null; _collapsedPaths.clear(); });
    } catch (_) {
      setState(() { _root = _defaultOutline(); _selectedPath = null; _collapsedPaths.clear(); });
    }
  }

  OutlineNode _defaultOutline() => OutlineNode(title: '大纲', children: [
    OutlineNode(title: '全书总纲', content: '在此编写全书总纲...\n\n包括：故事主线、核心冲突、世界观概述、主题思想', children: [
      OutlineNode(title: '大节点1', content: '', children: []),
    ]),
    OutlineNode(title: '分卷大纲', content: '各卷的阶段划分与主要剧情方向', children: [
      OutlineNode(title: '卷一：未命名', content: '第一卷概要...', children: [
        OutlineNode(title: '第1章', content: '章节概要...', children: []),
      ]),
    ]),
  ]);

  Future<void> _save() async {
    if (_root == null) return;
    await ChapterOutlineService().saveOutline(_novel!, _toMap(_root!));
  }

  // ===== 路径系统：空串=根节点，"0"=第1子，"0/0"=第1子的第1子 =====
  Map<String, dynamic> _toMap(OutlineNode n) => n.toJson();
  OutlineNode _fromMap(Map<String, dynamic> m) => OutlineNode.fromJson(m);

  OutlineNode? _nodeAt(String p) {
    if (_root == null) return null;
    final map = _toMap(_root!);
    final result = ChapterOutlineService().nodeAt(map, p);
    return result == null ? null : _fromMap(result);
  }

  int _depthOf(String p) => ChapterOutlineService().depthOf(p);

  _OutlineLevel _levelOf(String p) {
    final d = _depthOf(p);
    if (d == 0) return _OutlineLevel.root;
    if (d == 1) return _OutlineLevel.volume;
    if (d == 2) return _OutlineLevel.chapter;
    return _OutlineLevel.leaf;
  }

  String _levelLabel(_OutlineLevel l) {
    switch (l) { case _OutlineLevel.root: return '根'; case _OutlineLevel.volume: return '卷/篇'; case _OutlineLevel.chapter: return '章'; case _OutlineLevel.leaf: return '节'; }
  }

  Color _levelColor(_OutlineLevel l) {
    switch (l) { case _OutlineLevel.root: return Colors.teal; case _OutlineLevel.volume: return Colors.indigo; case _OutlineLevel.chapter: return Colors.orange; case _OutlineLevel.leaf: return Colors.grey; }
  }

/// parentPath下该叫什么名字
  String _autoName(String parentPath) {
    return ChapterOutlineService().autoName(_toMap(_root!), parentPath);
  }

  Future<void> _addChild(String parentPath) async {
    if (_root == null) return;
    final svc = ChapterOutlineService();
    final isAddVolume = parentPath == '1';
    final isAddChapter = parentPath.startsWith('1/') && _depthOf(parentPath) == 2;

    String? customName;
    if (isAddVolume) {
      final defaultName = svc.autoName(_toMap(_root!), parentPath);
      customName = await svc.showVolumeNameDialog(context, defaultName: defaultName);
      if (customName == null) return;
    } else if (isAddChapter) {
      customName = await svc.showChapterNameDialog(context);
      if (customName == null) return;
      // 章节名格式：第X章：名称 或 第X章：待定
      final autoTitle = svc.autoName(_toMap(_root!), parentPath);
      customName = '$autoTitle：$customName';
    }

    _doAddChild(parentPath, customName);
  }

  void _doAddChild(String parentPath, String? customName) {
    if (_root == null) return;
    final p = _nodeAt(parentPath); if (p == null) return;
    setState(() {
      final name = customName ?? _autoName(parentPath);
      p.children.add(OutlineNode(title: name, content: ''));
      _collapsedPaths.remove(parentPath);
      final newIdx = p.children.length - 1;
      _selectNode(parentPath.isEmpty ? '$newIdx' : '$parentPath/$newIdx');
    });
    _save();
  }

  Future<void> _addSibling(String nodePath) async {
    if (nodePath.isEmpty || _root == null) return;
    final svc = ChapterOutlineService();
    final isSiblingOfChapter = nodePath.startsWith('1/') && _depthOf(nodePath) == 3;
    final isSiblingOfVolume = nodePath.startsWith('1/') && _depthOf(nodePath) == 2;

    String? customName;
    if (isSiblingOfVolume) {
      final ls = nodePath.lastIndexOf('/');
      final parentPath = ls == -1 ? '' : nodePath.substring(0, ls);
      customName = await svc.showVolumeNameDialog(context, defaultName: svc.autoName(_toMap(_root!), parentPath));
      if (customName == null) return;
    } else if (isSiblingOfChapter) {
      customName = await svc.showChapterNameDialog(context);
      if (customName == null) return;
      final ls = nodePath.lastIndexOf('/');
      final parentPath = ls == -1 ? '' : nodePath.substring(0, ls);
      final autoTitle = svc.autoName(_toMap(_root!), parentPath);
      customName = '$autoTitle：$customName';
    }

    _doAddSibling(nodePath, customName);
  }

  void _doAddSibling(String nodePath, String? customName) {
    if (_root == null) return;
    final ls = nodePath.lastIndexOf('/');
    final parentPath = ls == -1 ? '' : nodePath.substring(0, ls);
    final p = _nodeAt(parentPath); if (p == null) return;
    setState(() {
      final name = customName ?? _autoName(parentPath);
      p.children.add(OutlineNode(title: name, content: ''));
      final newIdx = p.children.length - 1;
      _selectNode(parentPath.isEmpty ? '$newIdx' : '$parentPath/$newIdx');
    });
    _save();
  }

  void _deleteNode(String nodePath) {
    if (nodePath.isEmpty) return; // 不能删除根节点
    final ls = nodePath.lastIndexOf('/');
    final parentPath = ls == -1 ? '' : nodePath.substring(0, ls);
    final idx = int.parse(nodePath.substring(ls + 1));
    final p = _nodeAt(parentPath); if (p == null) return;
    setState(() { p.children.removeAt(idx); _selectedPath = null; });
    _save();
  }

  void _selectNode(String p) {
    final n = _nodeAt(p); if (n == null) return;
    _titleCtrl.text = n.title; _contentCtrl.text = n.content;
    setState(() => _selectedPath = p);
  }

  void _toggleCollapse(String p) {
    setState(() => _collapsedPaths.contains(p) ? _collapsedPaths.remove(p) : _collapsedPaths.add(p));
  }

  void _saveCurrent() {
    if (_selectedPath == null || _autoSavePending) return;
    _autoSavePending = true;
    Future.delayed(const Duration(milliseconds: 500), () {
      _autoSavePending = false;
      if (_selectedPath == null) return;
      final n = _nodeAt(_selectedPath!); if (n == null) return;
      n.title = _titleCtrl.text; n.content = _contentCtrl.text;
      _save(); setState(() {});
    });
  }

  // ===== BUILD =====
  @override
  Widget build(BuildContext context) {
    final n = context.watch<SelectedNovelProvider>().selectedNovel;
    if (n != _novel) WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    if (_novel == null) return const Center(child: Text('请先选择一部小说'));
    if (_root == null) return const Center(child: CircularProgressIndicator());

    return LayoutBuilder(builder: (ctx, constraints) {
      final h = constraints.maxHeight;
      final isWide = constraints.maxWidth > 600;
      if (isWide) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 280, height: h, child: _buildTreePanel()),
          const VerticalDivider(width: 1),
          Expanded(child: _buildEditor()),
        ]);
      } else {
        return Column(children: [
          SizedBox(height: 220, child: _buildTreePanel()),
          const Divider(height: 1),
          Expanded(child: _buildEditor()),
        ]);
      }
    });
  }

  // ===== 树面板 =====
  Widget _buildTreePanel() => Column(children: [
    Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey[50], border: const Border(bottom: BorderSide(color: Color(0xFFE0E0E0)))),
      child: Row(children: [
        const Icon(Icons.account_tree, size: 18, color: Colors.teal),
        const SizedBox(width: 8),
        const Text('大纲目录', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const Spacer(),
        _legendDot(Colors.indigo, '卷'),
        _legendDot(Colors.orange, '章'),
        const SizedBox(width: 8),
        InkWell(
          onTap: () {
            if (_selectedPath != null && _nodeAt(_selectedPath!) != null) {
              _addChild(_selectedPath!);
            } else {
              // 无选中时在根下添加（全书总纲或分卷大纲外的第三项）
              _addChild('');
            }
          },
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.teal.withAlpha(20), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.teal.withAlpha(80))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.add, size: 14, color: Colors.teal),
              const SizedBox(width: 2),
              Text(_selectedPath != null ? '＋子' : '＋根', style: const TextStyle(fontSize: 11, color: Colors.teal, fontWeight: FontWeight.w500)),
            ]),
          ),
        ),
      ]),
    ),
    Expanded(
      child: _root != null && _root!.children.isNotEmpty
        ? ListView(padding: const EdgeInsets.symmetric(vertical: 4), children: _buildTreeList('', _root!, 0))
        : Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.auto_stories, size: 36, color: Colors.grey[300]),
            const SizedBox(height: 8),
            Text('大纲为空', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            const SizedBox(height: 4),
            TextButton.icon(onPressed: () => _addChild(''), icon: const Icon(Icons.add, size: 16), label: const Text('添加一级节点', style: TextStyle(fontSize: 12))),
          ])),
    ),
  ]);

  Widget _legendDot(Color color, String label) => Padding(
    padding: const EdgeInsets.only(left: 6),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 2),
      Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
    ]),
  );

  List<Widget> _buildTreeList(String p, OutlineNode node, int depth) {
    final w = <Widget>[];
    final sel = _selectedPath == p;
    final level = _levelOf(p);
    final isRoot = depth == 0;
    final hasChildren = node.children.isNotEmpty;
    final isCollapsed = _collapsedPaths.contains(p);

    w.add(ListTile(
      onTap: () => _selectNode(p),
      selected: sel,
      selectedTileColor: _levelColor(level).withAlpha(20),
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: EdgeInsets.only(left: 8.0 + depth * 20, right: 8),
      minLeadingWidth: 0,
      leading: hasChildren
        ? GestureDetector(
            onTap: () => _toggleCollapse(p),
            child: Icon(isCollapsed ? Icons.keyboard_arrow_right : Icons.keyboard_arrow_down, size: 16, color: sel ? _levelColor(level) : Colors.grey[400]),
          )
        : const SizedBox(width: 16),
      title: Row(children: [
        if (!isRoot) Container(width: 6, height: 6, margin: const EdgeInsets.only(right: 8), decoration: BoxDecoration(color: _levelColor(level), shape: BoxShape.circle)),
        if (!isRoot) Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), margin: const EdgeInsets.only(right: 6), decoration: BoxDecoration(color: _levelColor(level).withAlpha(25), borderRadius: BorderRadius.circular(3)), child: Text(_levelLabel(level), style: TextStyle(fontSize: 9, color: _levelColor(level), fontWeight: FontWeight.w500))),
        Flexible(child: Text(node.title, style: TextStyle(fontSize: isRoot ? 14 : 13, fontWeight: isRoot ? FontWeight.bold : (sel ? FontWeight.w600 : FontWeight.normal), color: sel ? _levelColor(level) : null), maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
      trailing: sel
        ? Row(mainAxisSize: MainAxisSize.min, children: [
            if (ChapterOutlineService().canAddChild(_toMap(_root!), p))
              GestureDetector(onTap: () => _addChild(p), child: Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(3)), child: Text('＋子', style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.w500)))),
            if (ChapterOutlineService().canAddSibling(_toMap(_root!), p)) ...[
              const SizedBox(width: 2),
              GestureDetector(onTap: () => _addSibling(p), child: Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(3)), child: Text('＋同', style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.w500)))),
            ],
          ])
        : null,
    ));

    if (!isCollapsed) {
      for (var i = 0; i < node.children.length; i++) {
        w.addAll(_buildTreeList(p.isEmpty ? '$i' : '$p/$i', node.children[i], depth + 1));
      }
    }
    return w;
  }

  // ===== 编辑器 =====
  Widget _buildEditor() {
    if (_selectedPath == null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.touch_app, size: 48, color: Colors.grey[300]),
        const SizedBox(height: 16),
        Text('从左侧选择大纲节点进行编辑', style: TextStyle(fontSize: 15, color: Colors.grey[500])),
        const SizedBox(height: 8),
        Text('点击节点可编辑标题和内容\n使用「＋子」和「＋同」按钮添加节点', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey[400])),
        const SizedBox(height: 24),
        Row(mainAxisSize: MainAxisSize.min, children: [
          _quickBtn('添加总纲', Icons.book, () => _addChild('0')),
          const SizedBox(width: 12),
          _quickBtn('添加分卷', Icons.collections_bookmark, () => _addChild('1')),
          const SizedBox(width: 12),
          _quickBtn('添加章节', Icons.article, () {
            // 在第一卷下添加章节；若无卷则在分卷大纲下加卷再加章
            final volNode = _nodeAt('1');
            if (volNode != null && volNode.children.isNotEmpty) {
              _addChild('1/0');
            } else {
              _addChild('1');
            }
          }),
          const SizedBox(width: 12),
          _quickBtn('灵感建议', Icons.lightbulb, _showOutlineInspiration),
        ]),
      ]));
    }

    final level = _levelOf(_selectedPath!);
    final levelColor = _levelColor(level);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: Colors.grey[50], border: const Border(bottom: BorderSide(color: Color(0xFFE0E0E0)))),
        child: Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: levelColor.withAlpha(25), borderRadius: BorderRadius.circular(6), border: Border.all(color: levelColor.withAlpha(80))), child: Text(_levelLabel(level), style: TextStyle(fontSize: 12, color: levelColor, fontWeight: FontWeight.w600))),
          const SizedBox(width: 12),
          Expanded(child: Text(_buildBreadcrumb(_selectedPath!), style: TextStyle(fontSize: 12, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (ChapterOutlineService().canAddChild(_toMap(_root!), _selectedPath!))
            _toolBtn('＋子', Icons.subdirectory_arrow_right, () => _addChild(_selectedPath!)),
          if (ChapterOutlineService().canAddSibling(_toMap(_root!), _selectedPath!)) ...[
            const SizedBox(width: 4),
            _toolBtn('＋同', Icons.add, () => _addSibling(_selectedPath!)),
          ],
          const SizedBox(width: 4),
          _toolBtn('删除', Icons.delete_outline, () => _deleteNode(_selectedPath!), isRed: true),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: TextField(
          controller: _titleCtrl,
          decoration: InputDecoration(hintText: '输入标题...', border: const OutlineInputBorder(), isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), prefixIcon: Icon(Icons.title, size: 18, color: levelColor)),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          onChanged: (_) => _saveCurrent(),
        ),
      ),
      const SizedBox(height: 8),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: TextField(
            controller: _contentCtrl, maxLines: null, expands: true, textAlignVertical: TextAlignVertical.top,
            style: const TextStyle(fontSize: 15, height: 1.8),
            decoration: const InputDecoration(hintText: '在此编写大纲内容...', border: OutlineInputBorder(), contentPadding: EdgeInsets.all(14)),
            onChanged: (_) => _saveCurrent(),
          ),
        ),
      ),
    ]);
  }

  Widget _toolBtn(String label, IconData icon, VoidCallback onTap, {bool isRed = false}) {
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(color: isRed ? Colors.red.withAlpha(15) : Colors.grey[100], borderRadius: BorderRadius.circular(4), border: Border.all(color: isRed ? Colors.red.withAlpha(60) : Colors.grey[300]!)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: isRed ? Colors.red : Colors.grey[600]),
          const SizedBox(width: 2),
          Text(label, style: TextStyle(fontSize: 10, color: isRed ? Colors.red : Colors.grey[600], fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  String _buildBreadcrumb(String p) {
    final crumbs = <String>[_root!.title];
    if (p.isEmpty) return crumbs.join(' > ');
    var node = _root!;
    for (final s in p.split('/')) {
      final i = int.parse(s);
      if (i >= node.children.length) break;
      node = node.children[i];
      crumbs.add(node.title);
    }
    return crumbs.join(' > ');
  }

  // ===== 灵感建议 =====
  Future<void> _showOutlineInspiration() async {
    final buf = StringBuffer();
    void collect(OutlineNode n, int depth) { buf.writeln('${"  " * depth}${n.title}: ${n.content}'); for (final c in n.children) collect(c, depth + 1); }
    if (_root != null) collect(_root!, 0);
    final ctx = buf.toString();
    if (ctx.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('大纲为空'))); return; }
    await InspirationService().showInspirationDialog(
      context: context,
      cacheKey: 'outline_all',
      contextData: ctx,
      promptPrefix: '作为资深网文编辑，根据大纲提供3-5条创作灵感（剧情走向、人物发展、世界观拓展）',
      dialogTitle: '大纲灵感建议',
    );
  }

  Widget _quickBtn(String label, IconData icon, VoidCallback onTap) {
    return OutlinedButton.icon(onPressed: onTap, icon: Icon(icon, size: 16), label: Text(label, style: const TextStyle(fontSize: 12)), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), minimumSize: Size.zero));
  }

  @override void dispose() { _titleCtrl.dispose(); _contentCtrl.dispose(); super.dispose(); }
}

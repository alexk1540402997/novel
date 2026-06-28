import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as path;
import '../../domain/services/novel_folder_service.dart';
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

/// 层级类型
enum _OutlineLevel { root, volume, chapter, leaf }

class OutlinePage extends StatefulWidget {
  const OutlinePage({super.key});
  @override State<OutlinePage> createState() => _OutlinePageState();
}

class _OutlinePageState extends State<OutlinePage> {
  String? _novel; OutlineNode? _root; String? _selectedPath;
  final _titleCtrl = TextEditingController(), _contentCtrl = TextEditingController();
  bool _autoSavePending = false;
  /// 折叠状态：记录被折叠的节点路径（折叠后其子节点不渲染）
  final Set<String> _collapsedPaths = {};

  @override void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) => _check()); }

  void _check() {
    final n = context.read<SelectedNovelProvider>().selectedNovel;
    if (n != _novel) { _novel = n; if (n != null) _load(); }
  }

  Future<String> _filePath() async {
    final base = await NovelFolderService().getNovelsFolderPath();
    return path.join(base, _novel!, 'outline.json');
  }

  Future<void> _load() async {
    try {
      final fp = await _filePath(); final file = File(fp);
      _root = await file.exists() ? OutlineNode.fromJson(jsonDecode(await file.readAsString())) : _defaultOutline();
    } catch (_) { _root = _defaultOutline(); }
    setState(() { _selectedPath = null; _collapsedPaths.clear(); });
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
    final fp = await _filePath(); await File(fp).parent.create(recursive: true);
    await File(fp).writeAsString(jsonEncode(_root!.toJson()));
  }

  OutlineNode? _nodeAt(String p) {
    if (_root == null) return null;
    final parts = p.split('/').map(int.parse).toList(); var n = _root!;
    for (final i in parts) { if (i >= n.children.length) return null; n = n.children[i]; }
    return n;
  }

  int _depthOf(String path) => path.split('/').length - 1;

  _OutlineLevel _levelOf(String path) {
    final d = _depthOf(path);
    if (d == 0) return _OutlineLevel.root;
    if (d == 1) return _OutlineLevel.volume;
    if (d == 2) return _OutlineLevel.chapter;
    return _OutlineLevel.leaf;
  }

  String _levelLabel(_OutlineLevel level) {
    switch (level) {
      case _OutlineLevel.root: return '根';
      case _OutlineLevel.volume: return '卷/篇';
      case _OutlineLevel.chapter: return '章';
      case _OutlineLevel.leaf: return '节';
    }
  }

  Color _levelColor(_OutlineLevel level) {
    switch (level) {
      case _OutlineLevel.root: return Colors.teal;
      case _OutlineLevel.volume: return Colors.indigo;
      case _OutlineLevel.chapter: return Colors.orange;
      case _OutlineLevel.leaf: return Colors.grey;
    }
  }

  /// 判断路径对应的父节点是否为"全书总纲"或其子节点
  bool _isUnderWholeBook(String path) {
    if (_root == null) return false;
    final parts = path.split('/').map(int.parse).toList();
    if (parts.isEmpty || parts[0] >= _root!.children.length) return false;
    // 第一个子节点是"全书总纲"
    final firstChild = _root!.children.isNotEmpty ? _root!.children[0].title : '';
    if (!firstChild.contains('全书总纲') && !firstChild.contains('总纲')) return false;
    return parts[0] == 0;
  }

  /// 判断路径对应的父节点是否为"分卷大纲"或其子节点
  bool _isUnderVolumes(String path) {
    if (_root == null) return false;
    final parts = path.split('/').map(int.parse).toList();
    if (parts.isEmpty || parts[0] >= _root!.children.length) return false;
    final secondChild = _root!.children.length > 1 ? _root!.children[1].title : '';
    if (!secondChild.contains('分卷') && !secondChild.contains('卷大纲')) return false;
    return parts[0] == 1;
  }

  /// 智能命名：根据父节点上下文自动生成子节点名称
  String _autoName(String parentPath) {
    final parent = _nodeAt(parentPath);
    final depth = _depthOf(parentPath) + 1;
    final existingCount = parent?.children.length ?? 0;
    final newIndex = existingCount + 1;

    // 判断父节点类型
    final grandparentPath = parentPath.contains('/')
        ? parentPath.substring(0, parentPath.lastIndexOf('/'))
        : '';

    // 全书总纲下的子节点 → 大节点N
    if (_isUnderWholeBook(parentPath)) {
      if (depth == 2) return '大节点$newIndex';
      if (depth >= 3) return '小节点$newIndex';
    }
    // 之前已经在全书总纲下的分支内
    if (parentPath == '0') {
      // parent是全书总纲本身 → 它的子节点叫"大节点N"
      return '大节点$newIndex';
    }

    // 分卷大纲下的子节点 → 卷N：未命名
    if (parentPath == '1') {
      return '卷$newIndex：未命名';
    }
    // 分卷大纲下更深层级
    if (_isUnderVolumes(parentPath)) {
      if (depth == 3) return '第$newIndex章';
      if (depth > 3) return '小节点$newIndex';
    }

    // 通用回退
    switch (depth) {
      case 1: return '大节点$newIndex';
      case 2: return '第$newIndex章';
      default: return '小节点$newIndex';
    }
  }

  void _addChild(String parentPath) {
    final p = _nodeAt(parentPath); if (p == null) return;
    setState(() {
      final name = _autoName(parentPath);
      p.children.add(OutlineNode(title: name, content: ''));
      // 自动展开父节点
      _collapsedPaths.remove(parentPath);
      _selectNode('$parentPath/${p.children.length - 1}');
    });
    _save();
  }

  void _addSibling(String path) {
    if (path == '0') return;
    final ls = path.lastIndexOf('/');
    final pp = path.substring(0, ls);
    final p = _nodeAt(pp); if (p == null) return;
    final name = _autoName(pp);
    setState(() {
      p.children.add(OutlineNode(title: name, content: ''));
      _selectNode('$pp/${p.children.length - 1}');
    });
    _save();
  }

  void _deleteNode(String path) {
    if (path == '0') return;
    final ls = path.lastIndexOf('/');
    final pp = path.substring(0, ls); final idx = int.parse(path.substring(ls + 1));
    final p = _nodeAt(pp); if (p == null) return;
    setState(() { p.children.removeAt(idx); _selectedPath = null; });
    _save();
  }

  void _selectNode(String path) {
    final n = _nodeAt(path); if (n == null) return;
    _titleCtrl.text = n.title; _contentCtrl.text = n.content;
    setState(() => _selectedPath = path);
  }

  void _toggleCollapse(String path) {
    setState(() {
      if (_collapsedPaths.contains(path)) {
        _collapsedPaths.remove(path);
      } else {
        _collapsedPaths.add(path);
      }
    });
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

  @override
  Widget build(BuildContext context) {
    final n = context.watch<SelectedNovelProvider>().selectedNovel;
    if (n != _novel) WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    if (_novel == null) return const Center(child: Text('请先选择一部小说'));
    if (_root == null) return const Center(child: CircularProgressIndicator());

    return LayoutBuilder(builder: (ctx, constraints) {
      final isWide = constraints.maxWidth > 600;
      if (isWide) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 280, child: _buildTreePanel()),
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

  Widget _buildTreePanel() => Column(children: [
    Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: const Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
      ),
      child: Row(children: [
        const Icon(Icons.account_tree, size: 18, color: Colors.teal),
        const SizedBox(width: 8),
        const Text('大纲目录', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const Spacer(),
        // 图例
        _legendDot(Colors.indigo, '卷'),
        _legendDot(Colors.orange, '章'),
        const SizedBox(width: 8),
        // 上下文感知的添加按钮
        InkWell(
          onTap: () {
            // 如果有选中节点，在其下添加子节点；否则在根下添加
            if (_selectedPath != null && _nodeAt(_selectedPath!) != null) {
              _addChild(_selectedPath!);
            } else {
              _addChild('0');
            }
          },
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.teal.withAlpha(20),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.teal.withAlpha(80)),
            ),
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
        ? ListView(
            padding: const EdgeInsets.symmetric(vertical: 4),
            children: _buildTreeList('0', _root!, 0),
          )
        : Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.auto_stories, size: 36, color: Colors.grey[300]),
              const SizedBox(height: 8),
              Text('大纲为空', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: () => _addChild('0'),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('添加一级节点', style: TextStyle(fontSize: 12)),
              ),
            ]),
          ),
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

  List<Widget> _buildTreeList(String path, OutlineNode node, int depth) {
    final w = <Widget>[];
    final sel = _selectedPath == path;
    final level = _levelOf(path);
    final isRoot = depth == 0;
    final hasChildren = node.children.isNotEmpty;
    final isCollapsed = _collapsedPaths.contains(path);

    // 用 ListTile 确保点击可靠
    w.add(ListTile(
      onTap: () => _selectNode(path),
      selected: sel,
      selectedTileColor: _levelColor(level).withAlpha(20),
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: EdgeInsets.only(left: 8.0 + depth * 20, right: 8),
      minLeadingWidth: 0,
      // 折叠箭头或占位
      leading: hasChildren
          ? GestureDetector(
              onTap: () => _toggleCollapse(path),
              child: Icon(
                isCollapsed ? Icons.keyboard_arrow_right : Icons.keyboard_arrow_down,
                size: 16,
                color: sel ? _levelColor(level) : Colors.grey[400],
              ),
            )
          : const SizedBox(width: 16),
      // 标题
      title: Row(children: [
        if (!isRoot)
          Container(
            width: 6, height: 6,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: _levelColor(level),
              shape: BoxShape.circle,
            ),
          ),
        if (!isRoot)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: _levelColor(level).withAlpha(25),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(_levelLabel(level), style: TextStyle(fontSize: 9, color: _levelColor(level), fontWeight: FontWeight.w500)),
          ),
        Flexible(
          child: Text(
            node.title,
            style: TextStyle(
              fontSize: isRoot ? 14 : 13,
              fontWeight: isRoot ? FontWeight.bold : (sel ? FontWeight.w600 : FontWeight.normal),
              color: sel ? _levelColor(level) : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
      // 选中时显示操作按钮
      trailing: sel
          ? Row(mainAxisSize: MainAxisSize.min, children: [
              GestureDetector(
                onTap: () => _addChild(path),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text('＋子', style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                ),
              ),
              if (path != '0') ...[
                const SizedBox(width: 2),
                GestureDetector(
                  onTap: () => _addSibling(path),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text('＋同', style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                  ),
                ),
              ],
            ])
          : null,
    ));

    // 递归渲染子节点
    if (!isCollapsed) {
      for (var i = 0; i < node.children.length; i++) {
        w.addAll(_buildTreeList('$path/$i', node.children[i], depth + 1));
      }
    }
    return w;
  }

  Widget _buildEditor() {
    if (_selectedPath == null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.touch_app, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('从左侧选择大纲节点进行编辑', style: TextStyle(fontSize: 15, color: Colors.grey[500])),
          const SizedBox(height: 8),
          Text('点击节点可编辑标题和内容\n使用「＋子」和「＋同」按钮添加节点', textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey[400])),
          const SizedBox(height: 24),
          // 快速操作按钮
          Row(mainAxisSize: MainAxisSize.min, children: [
            _quickBtn('添加总纲', Icons.book, () => _addChild('0')),
            const SizedBox(width: 12),
            _quickBtn('添加分卷', Icons.collections_bookmark, () {
              if (_root != null && _root!.children.length > 1) {
                _addChild('0/1');
              } else {
                _addChild('0');
              }
            }),
            const SizedBox(width: 12),
            _quickBtn('添加章节', Icons.article, () {
              // 在分卷大纲的第一个卷下面添加章节
              if (_root != null && _root!.children.length > 1 && _root!.children[1].children.isNotEmpty) {
                _addChild('0/1/0');
              } else {
                _addChild('0');
              }
            }),
          ]),
        ]),
      );
    }

    final level = _levelOf(_selectedPath!);
    final levelColor = _levelColor(level);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // 编辑器工具栏
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          border: const Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
        ),
        child: Row(children: [
          // 层级标签
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: levelColor.withAlpha(25),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: levelColor.withAlpha(80)),
            ),
            child: Text(_levelLabel(level), style: TextStyle(fontSize: 12, color: levelColor, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 12),
          // 路径面包屑
          Expanded(
            child: Text(
              _buildBreadcrumb(_selectedPath!),
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
          ),
          // 操作按钮（文字标签）
          _toolBtn('＋子', Icons.subdirectory_arrow_right, () => _addChild(_selectedPath!)),
          const SizedBox(width: 4),
          _toolBtn('＋同', Icons.add, () => _addSibling(_selectedPath!)),
          const SizedBox(width: 4),
          _toolBtn('删除', Icons.delete_outline, () => _deleteNode(_selectedPath!), isRed: true),
        ]),
      ),
      // 标题编辑
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: TextField(
          controller: _titleCtrl,
          decoration: InputDecoration(
            hintText: '输入标题...',
            border: const OutlineInputBorder(),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            prefixIcon: Icon(Icons.title, size: 18, color: levelColor),
          ),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          onChanged: (_) => _saveCurrent(),
        ),
      ),
      const SizedBox(height: 8),
      // 内容编辑
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: TextField(
            controller: _contentCtrl,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: const TextStyle(fontSize: 15, height: 1.8),
            decoration: const InputDecoration(
              hintText: '在此编写大纲内容...\n\n💡 提示：\n• 总纲 → 写故事主线、核心冲突、主题思想\n• 分卷 → 写每卷的故事阶段、主要事件、角色发展\n• 章节 → 写单章情节、场景、角色互动、伏笔线索',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(14),
            ),
            onChanged: (_) => _saveCurrent(),
          ),
        ),
      ),
    ]);
  }

  /// 工具栏文字按钮
  Widget _toolBtn(String label, IconData icon, VoidCallback onTap, {bool isRed = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: isRed ? Colors.red.withAlpha(15) : Colors.grey[100],
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: isRed ? Colors.red.withAlpha(60) : Colors.grey[300]!),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: isRed ? Colors.red : Colors.grey[600]),
          const SizedBox(width: 2),
          Text(label, style: TextStyle(fontSize: 10, color: isRed ? Colors.red : Colors.grey[600], fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  String _buildBreadcrumb(String path) {
    final parts = path.split('/').map(int.parse).toList();
    final crumbs = <String>[];
    var node = _root!;
    crumbs.add(node.title);
    for (var i = 1; i < parts.length; i++) {
      if (parts[i] < node.children.length) {
        node = node.children[parts[i]];
        crumbs.add(node.title);
      }
    }
    return crumbs.join(' > ');
  }

  Widget _quickBtn(String label, IconData icon, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
      ),
    );
  }

  @override void dispose() { _titleCtrl.dispose(); _contentCtrl.dispose(); super.dispose(); }
}

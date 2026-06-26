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

class OutlinePage extends StatefulWidget {
  const OutlinePage({super.key});
  @override State<OutlinePage> createState() => _OutlinePageState();
}

class _OutlinePageState extends State<OutlinePage> {
  String? _novel; OutlineNode? _root; String? _selectedPath;
  final _titleCtrl = TextEditingController(), _contentCtrl = TextEditingController();

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
    setState(() => _selectedPath = null);
  }

  OutlineNode _defaultOutline() => OutlineNode(title: '大纲', children: [
    OutlineNode(title: '全书大纲', content: '在此编写全书总纲...', children: []),
    OutlineNode(title: '分卷大纲', children: [OutlineNode(title: '第一卷', content: '第一卷概要...', children: [])]),
    OutlineNode(title: '章节大纲', children: [OutlineNode(title: '第1章', content: '章节概要...', children: [])]),
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

  void _addChild(String parentPath) {
    final p = _nodeAt(parentPath); if (p == null) return;
    setState(() {
      p.children.add(OutlineNode(title: '新节点', content: ''));
      _selectNode('$parentPath/${p.children.length - 1}');
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

  void _saveCurrent() {
    if (_selectedPath == null) return;
    final n = _nodeAt(_selectedPath!); if (n == null) return;
    n.title = _titleCtrl.text; n.content = _contentCtrl.text;
    _save(); setState(() {});
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
          SizedBox(width: 260, child: _buildTreePanel()),
          const VerticalDivider(width: 1),
          Expanded(child: _buildEditor()),
        ]);
      } else {
        // 手机端：树和编辑器上下排列
        return Column(children: [
          SizedBox(height: 200, child: _buildTreePanel()),
          const Divider(height: 1),
          Expanded(child: _buildEditor()),
        ]);
      }
    });
  }

  Widget _buildTreePanel() => Column(children: [
    Padding(padding: const EdgeInsets.all(8), child: Row(children: [
      const Text('📋 大纲目录', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      const Spacer(),
      IconButton(icon: const Icon(Icons.add, size: 18), onPressed: () {
        // 在当前选中的节点下添加子节点，未选中则在根下添加
        _addChild(_selectedPath ?? '0');
      }, tooltip: '添加子节点'),
    ])),
    const Divider(height: 1),
    Expanded(child: ListView(padding: const EdgeInsets.all(4), children: _root != null ? _buildTree('0', _root!, 0) : [])),
  ]);

  List<Widget> _buildTree(String path, OutlineNode node, int depth) {
    final w = <Widget>[];
    final sel = _selectedPath == path;
    w.add(InkWell(
      onTap: () => _selectNode(path),
      child: Container(
        color: sel ? Colors.teal.withAlpha(30) : null,
        padding: EdgeInsets.only(left: 8.0 + depth * 20, right: 8, top: 8, bottom: 8),
        child: Row(children: [
          Icon(node.children.isNotEmpty ? Icons.folder_outlined : Icons.article_outlined, size: 16, color: sel ? Colors.teal : Colors.grey),
          const SizedBox(width: 6),
          Expanded(child: Text(node.title, style: TextStyle(fontSize: 13, fontWeight: sel ? FontWeight.bold : FontWeight.normal))),
          IconButton(icon: const Icon(Icons.add_circle_outline, size: 16), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => _addChild(path), tooltip: '添加子节点'),
        ]),
      ),
    ));
    for (var i = 0; i < node.children.length; i++) {
      w.addAll(_buildTree('$path/$i', node.children[i], depth + 1));
    }
    return w;
  }

  Widget _buildEditor() => _selectedPath == null
    ? const Center(child: Text('👈 从左侧选择大纲节点进行编辑', style: TextStyle(color: Colors.grey)))
    : Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: Row(children: [
          Expanded(child: TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: '标题', border: OutlineInputBorder(), isDense: true), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), onChanged: (_) => _saveCurrent())),
          const SizedBox(width: 8),
          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deleteNode(_selectedPath!), tooltip: '删除'),
        ])),
        const Divider(height: 1),
        Expanded(child: TextField(controller: _contentCtrl, maxLines: null, expands: true, textAlignVertical: TextAlignVertical.top, style: const TextStyle(fontSize: 15, height: 1.8), decoration: const InputDecoration(hintText: '在此编写大纲内容...', border: InputBorder.none, contentPadding: EdgeInsets.all(16)), onChanged: (_) => _saveCurrent())),
      ]);

  @override void dispose() { _titleCtrl.dispose(); _contentCtrl.dispose(); super.dispose(); }
}

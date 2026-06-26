import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as path;
import '../../domain/services/novel_folder_service.dart';
import '../pages/novel_architecture_page.dart'; // SelectedNovelProvider

/// 大纲条目
class OutlineNode {
  String title;
  String content;
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
  @override
  State<OutlinePage> createState() => _OutlinePageState();
}

class _OutlinePageState extends State<OutlinePage> {
  String? _novel;
  OutlineNode? _root;
  String? _selectedPath; // "0/1/2" style path
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();

  @override
  void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) => _check()); }

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
      final fp = await _filePath();
      final file = File(fp);
      if (await file.exists()) {
        _root = OutlineNode.fromJson(jsonDecode(await file.readAsString()));
      } else {
        _root = _defaultOutline();
      }
    } catch (_) { _root = _defaultOutline(); }
    setState(() => _selectedPath = null);
  }

  OutlineNode _defaultOutline() => OutlineNode(title: '大纲', children: [
    OutlineNode(title: '全书大纲', content: '在此编写全书总纲...', children: []),
    OutlineNode(title: '分卷大纲', children: [
      OutlineNode(title: '第一卷', content: '第一卷概要...', children: []),
    ]),
    OutlineNode(title: '章节大纲', children: [
      OutlineNode(title: '第1章', content: '章节概要...', children: []),
    ]),
  ]);

  Future<void> _save() async {
    if (_root == null) return;
    final fp = await _filePath();
    await File(fp).parent.create(recursive: true);
    await File(fp).writeAsString(jsonEncode(_root!.toJson()));
  }

  OutlineNode? _nodeAt(String path) {
    if (_root == null) return null;
    final parts = path.split('/').map(int.parse).toList();
    var node = _root!;
    for (final i in parts) { if (i >= node.children.length) return null; node = node.children[i]; }
    return node;
  }

  void _addChild(String parentPath) {
    final parent = _nodeAt(parentPath);
    if (parent == null) return;
    setState(() => parent.children.add(OutlineNode(title: '新节点', content: '')));
    _save();
  }

  void _deleteNode(String path) {
    if (path == '0') return; // 不删除根
    final lastSlash = path.lastIndexOf('/');
    final parentPath = path.substring(0, lastSlash);
    final idx = int.parse(path.substring(lastSlash + 1));
    final parent = _nodeAt(parentPath);
    if (parent == null) return;
    setState(() { parent.children.removeAt(idx); _selectedPath = null; });
    _save();
  }

  void _selectNode(String path) {
    final node = _nodeAt(path);
    if (node == null) return;
    _titleCtrl.text = node.title;
    _contentCtrl.text = node.content;
    setState(() => _selectedPath = path);
  }

  void _saveCurrent() {
    if (_selectedPath == null) return;
    final node = _nodeAt(_selectedPath!);
    if (node == null) return;
    node.title = _titleCtrl.text;
    node.content = _contentCtrl.text;
    _save();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final n = context.watch<SelectedNovelProvider>().selectedNovel;
    if (n != _novel) WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    if (_novel == null) return const Center(child: Text('请先选择一部小说'));
    if (_root == null) return const Center(child: CircularProgressIndicator());

    return Row(children: [
      // 左侧大纲树
      SizedBox(width: 260, child: Column(children: [
        Padding(padding: const EdgeInsets.all(8), child: Row(children: [
          const Text('📋 大纲目录', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const Spacer(),
          IconButton(icon: const Icon(Icons.add, size: 18), onPressed: () => _addChild('0'), tooltip: '添加根节点'),
        ])),
        const Divider(height: 1),
        Expanded(child: ListView(padding: const EdgeInsets.all(8), children: _buildTree('0', _root!, 0))),
      ])),
      const VerticalDivider(width: 1),
      // 右侧编辑区
      Expanded(child: _selectedPath == null
        ? const Center(child: Text('👈 从左侧选择大纲节点进行编辑', style: TextStyle(color: Colors.grey)))
        : Column(children: [
          Padding(padding: const EdgeInsets.all(12), child: Row(children: [
            Expanded(child: TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: '标题', border: OutlineInputBorder(), isDense: true), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            const SizedBox(width: 12),
            FilledButton.icon(onPressed: _saveCurrent, icon: const Icon(Icons.save, size: 16), label: const Text('保存')),
            const SizedBox(width: 8),
            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deleteNode(_selectedPath!), tooltip: '删除'),
            const SizedBox(width: 4),
            IconButton(icon: const Icon(Icons.add), onPressed: () => _addChild(_selectedPath!), tooltip: '添加子节点'),
          ])),
          const Divider(height: 1),
          Expanded(child: TextField(controller: _contentCtrl, maxLines: null, expands: true, textAlignVertical: TextAlignVertical.top,
            style: const TextStyle(fontSize: 15, height: 1.8),
            decoration: const InputDecoration(hintText: '在此编写大纲内容...', border: InputBorder.none, contentPadding: EdgeInsets.all(16)),
          )),
        ]),
      ),
    ]);
  }

  List<Widget> _buildTree(String path, OutlineNode node, int depth) {
    final widgets = <Widget>[];
    final isSelected = _selectedPath == path;
    final hasChildren = node.children.isNotEmpty;

    widgets.add(
      InkWell(
        onTap: () => _selectNode(path),
        child: Container(
          color: isSelected ? Colors.teal.withAlpha(25) : null,
          padding: EdgeInsets.only(left: 12.0 + depth * 16, right: 8, top: 6, bottom: 6),
          child: Row(children: [
            Icon(hasChildren ? Icons.folder_outlined : Icons.article_outlined, size: 16, color: isSelected ? Colors.teal : Colors.grey),
            const SizedBox(width: 6),
            Expanded(child: Text(node.title, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal))),
          ]),
        ),
      ),
    );

    for (var i = 0; i < node.children.length; i++) {
      widgets.addAll(_buildTree('$path/$i', node.children[i], depth + 1));
    }
    return widgets;
  }

  @override
  void dispose() { _titleCtrl.dispose(); _contentCtrl.dispose(); super.dispose(); }
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/character.dart';
import '../../domain/services/character_service.dart';
import '../../domain/services/image_generation_service.dart';
import '../../domain/services/inspiration_service.dart';
import '../../domain/services/novel_folder_service.dart';
import '../pages/novel_architecture_page.dart'; // SelectedNovelProvider

class CharacterPage extends StatefulWidget {
  const CharacterPage({super.key});
  @override
  State<CharacterPage> createState() => _CharacterPageState();
}

class _CharacterPageState extends State<CharacterPage> {
  List<NovelCharacter> _allChars = [];
  List<NovelCharacter> _filtered = [];
  String? _roleFilter; // null = 显示"分类"提示, 筛选全部
  String _search = '';
  bool _loading = false;
  String? _novel;
  String? _detectedAudience;
  final _svc = CharacterService();
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    final n = context.read<SelectedNovelProvider>().selectedNovel;
    if (n != _novel) {
      _novel = n;
      if (n != null) _load();
    }
  }

  Future<void> _detectAudience() async {
    if (_novel == null) return;
    try {
      final base = await NovelFolderService().getNovelsFolderPath();
      final f = File('$base/$_novel/worldbook.json');
      if (await f.exists()) {
        final list = jsonDecode(await f.readAsString()) as List;
        if (list.isNotEmpty) {
          final notes = list.first['notes'] as String? ?? '';
          if (notes.contains('女频')) {
            _detectedAudience = '女频';
          } else if (notes.contains('男频')) {
            _detectedAudience = '男频';
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    if (_novel == null) return;
    setState(() => _loading = true);
    final items = await _svc.loadAll(_novel!);
    setState(() {
      _allChars = items;
      _loading = false;
      _apply();
    });
    await _detectAudience();
  }

  void _apply() {
    var l = _allChars;
    if (_roleFilter != null && _roleFilter != '全部') l = l.where((c) => c.role == _roleFilter).toList();
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      l = l.where((c) =>
          c.name.toLowerCase().contains(q) ||
          c.faction.toLowerCase().contains(q) ||
          c.personality.any((p) => p.toLowerCase().contains(q))).toList();
    }
    setState(() => _filtered = l);
  }

  Future<void> _delete(NovelCharacter c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('删除角色「${c.name}」？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('删除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true && _novel != null) {
      await _svc.delete(_novel!, c.id);
      _load();
    }
  }

  Future<void> _edit({NovelCharacter? existing}) async {
    if (_novel == null) return;
    final isNew = existing == null;
    final c = existing ??
        NovelCharacter(
            id: DateTime.now().millisecondsSinceEpoch.toString(), name: '');
    String name = c.name, gender = c.gender, age = c.age,
        appearance = c.appearance, role = c.role, faction = c.faction,
        status = c.currentStatus, notes = c.notes;
    String personalityStr = c.personality.join('、');
    String abilityStr = c.abilities.join('、');
    bool genImage = false;
    int firstCh = c.firstChapter;

    final r = await showDialog<NovelCharacter>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          return AlertDialog(
            title: null, // 不使用默认标题，避免背景遮挡内容
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 自定义标题
                  Row(children: [
                    Icon(Icons.person, color: Colors.teal, size: 22),
                    const SizedBox(width: 8),
                    Text(isNew ? '新增角色' : '编辑角色',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: const InputDecoration(
                        labelText: '姓名*', border: OutlineInputBorder(), isDense: true),
                    controller: TextEditingController(text: name),
                    onChanged: (v) => name = v,
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: gender,
                        decoration: const InputDecoration(
                            labelText: '性别', border: OutlineInputBorder(), isDense: true),
                        items: ['男', '女', '其他']
                            .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                            .toList(),
                        onChanged: (v) => setD(() => gender = v ?? '男'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                            labelText: '年龄', border: OutlineInputBorder(), isDense: true),
                        controller: TextEditingController(text: age),
                        onChanged: (v) => age = v,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: getCharacterRolesForAudience(_detectedAudience).contains(role) ? role : '其他',
                    decoration: const InputDecoration(
                        labelText: '角色定位', border: OutlineInputBorder(), isDense: true),
                    items: getCharacterRolesForAudience(_detectedAudience)
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: (v) {
                      if (v == '其他') {
                        setD(() => role = '');
                      } else {
                        setD(() => role = v ?? '配角');
                      }
                    },
                  ),
                  // 当选择"其他"或role不在预设列表中时，显示手动输入框
                  if (!getCharacterRolesForAudience(_detectedAudience).contains(role) && role != '其他')
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: TextField(
                        decoration: const InputDecoration(
                            labelText: '自定义角色定位', border: OutlineInputBorder(), isDense: true,
                            hintText: '输入自定义角色定位，如"女主/红颜"'),
                        controller: TextEditingController(text: role),
                        onChanged: (v) => role = v,
                      ),
                    ),
                  if (isNew)
                    CheckboxListTile(
                      title: const Text('生成角色插图', style: TextStyle(fontSize: 14)),
                      subtitle: const Text('AI将根据角色信息生成插图', style: TextStyle(fontSize: 11)),
                      value: genImage,
                      onChanged: (v) => setD(() => genImage = v ?? false),
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  const SizedBox(height: 10),
                  TextField(
                    decoration: const InputDecoration(
                        labelText: '所属势力', border: OutlineInputBorder(), isDense: true),
                    controller: TextEditingController(text: faction),
                    onChanged: (v) => faction = v,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    decoration: const InputDecoration(
                        labelText: '外貌描述', border: OutlineInputBorder(), isDense: true),
                    controller: TextEditingController(text: appearance),
                    onChanged: (v) => appearance = v,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    decoration: const InputDecoration(
                        labelText: '性格标签(、分隔)', border: OutlineInputBorder(), isDense: true),
                    controller: TextEditingController(text: personalityStr),
                    onChanged: (v) => personalityStr = v,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    decoration: const InputDecoration(
                        labelText: '能力/技能(、分隔)', border: OutlineInputBorder(), isDense: true),
                    controller: TextEditingController(text: abilityStr),
                    onChanged: (v) => abilityStr = v,
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    const Text('首次出场章节: '),
                    IconButton(
                        icon: const Icon(Icons.remove, size: 16),
                        onPressed: () =>
                            setD(() { if (firstCh > 0) firstCh--; })),
                    Text('$firstCh', style: const TextStyle(fontSize: 14)),
                    IconButton(
                        icon: const Icon(Icons.add, size: 16),
                        onPressed: () => setD(() => firstCh++)),
                  ]),
                  const SizedBox(height: 10),
                  TextField(
                    decoration: const InputDecoration(
                        labelText: '当前状态', border: OutlineInputBorder(), isDense: true),
                    controller: TextEditingController(text: status),
                    onChanged: (v) => status = v,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    decoration: const InputDecoration(
                        labelText: '备注', border: OutlineInputBorder(), isDense: true),
                    controller: TextEditingController(text: notes),
                    onChanged: (v) => notes = v,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
              FilledButton(
                onPressed: () {
                  if (name.trim().isEmpty) {
                    ScaffoldMessenger.of(ctx)
                        .showSnackBar(const SnackBar(content: Text('请输入姓名')));
                    return;
                  }
                  final updated = NovelCharacter(
                    id: c.id, name: name.trim(), gender: gender, age: age,
                    appearance: appearance,
                    personality: personalityStr.split('、').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
                    role: role, faction: faction,
                    abilities: abilityStr.split('、').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
                    relationships: c.relationships,
                    firstChapter: firstCh, keyEvents: c.keyEvents,
                    currentStatus: status, notes: notes, imagePath: c.imagePath, createdAt: c.createdAt,
                  );
                  Navigator.pop(ctx, updated);
                },
                child: Text(isNew ? '添加' : '保存'),
              ),
            ],
          );
        },
      ),
    );

    if (r != null && _novel != null) {
      if (isNew) await _svc.add(_novel!, r);
      else await _svc.update(_novel!, r);
      await _load();
      if (genImage) {
        await _generateCharacterImage(r);
      }
    }
  }

  Future<void> _generateCharacterImage(NovelCharacter c) async {
    if (_novel == null) return;
    final desc = StringBuffer();
    desc.writeln('角色：${c.name}，${c.gender}，${c.age}');
    if (c.appearance.isNotEmpty) desc.writeln('外貌：${c.appearance}');
    if (c.personality.isNotEmpty) desc.writeln('性格：${c.personality.join("、")}');
    if (c.faction.isNotEmpty) desc.writeln('势力：${c.faction}');
    desc.writeln('风格：Chinese illustration/animation style, character portrait');
    try {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      final imagePath = await ImageGenerationService().generateSceneImage(
        sceneText: desc.toString(),
        novelName: _novel!,
        chapterNum: c.firstChapter,
      );
      if (!mounted) return;
      Navigator.pop(context); // dismiss loading
      if (imagePath != null) {
        c.imagePath = imagePath;
        await _svc.update(_novel!, c);
        await _load();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生成角色图失败：$e')),
        );
      }
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case '主角': return Colors.amber;
      case '重要配角': return Colors.blue;
      case '反派': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = context.watch<SelectedNovelProvider>().selectedNovel;
    if (n != _novel) WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    if (_novel == null) return const Center(child: Text('请先选择一部小说'));

    return Column(children: [
      _toolbar(),
      _statsBar(),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _filtered.isEmpty
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.people_outline, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(_allChars.isEmpty ? '角色库为空，点击+添加' : '没有匹配的角色',
                          style: TextStyle(color: Colors.grey[600])),
                    ]))
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 280,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.85),
                    itemCount: _filtered.length,
                    itemBuilder: (ctx, i) => _card(_filtered[i]),
                  ),
      ),
    ]);
  }

  Widget _toolbar() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Row(children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                  hintText: '搜索角色...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              onChanged: (v) { _search = v; _apply(); },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _roleFilter,
              hint: const Text('分类', style: TextStyle(fontSize: 13, color: Colors.grey)),
              decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              items: ['全部', ...getCharacterRolesForAudience(_detectedAudience)]
                  .map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: (v) { setState(() { _roleFilter = v; _apply(); }); },
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: _showCharacterInspiration,
            icon: const Icon(Icons.lightbulb, size: 16, color: Colors.orange),
            label: const Text('灵感', style: TextStyle(color: Colors.orange)),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => _edit(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('添加'),
          ),
        ]),
      );

  Future<void> _showCharacterInspiration() async {
    final ctxBuf = StringBuffer();
    if (_allChars.isNotEmpty) {
      for (final c in _allChars) { ctxBuf.writeln('${c.role}·${c.name}: ${(c.personality ?? []).join("、")} ${c.faction ?? ""} ${(c.abilities ?? []).join("、")}'); }
    }
    await InspirationService().showInspirationDialog(
      context: context, cacheKey: 'character_all', contextData: ctxBuf.toString(),
      promptPrefix: '作为网文角色设计师，提供3-5条角色发展灵感（角色弧光、关系发展、隐藏身份）',
      dialogTitle: '角色灵感',
      emptyFallback: '网文小说角色设计，包括主角、反派、配角等角色的性格弧光和关系网络',
    );
  }

  /// 单个角色灵感
  Future<void> _showItemInspiration(NovelCharacter c) async {
    final ctxBuf = StringBuffer();
    ctxBuf.writeln('角色名：${c.name}');
    ctxBuf.writeln('定位：${c.role}');
    ctxBuf.writeln('性别：${c.gender}');
    if (c.faction.isNotEmpty) ctxBuf.writeln('势力：${c.faction}');
    if (c.personality.isNotEmpty) ctxBuf.writeln('性格：${c.personality.join("、")}');
    if (c.abilities.isNotEmpty) ctxBuf.writeln('能力：${c.abilities.join("、")}');
    if (c.notes.isNotEmpty) ctxBuf.writeln('备注：${c.notes}');
    await InspirationService().showInspirationDialog(
      context: context,
      cacheKey: 'character_item_${c.id}',
      contextData: ctxBuf.toString(),
      promptPrefix: '针对以下角色，提供3-5条角色发展和关系深化灵感',
      dialogTitle: '「${c.name}」灵感',
    );
  }

  Widget _statsBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        _chip('全部', _allChars.length, Colors.blue),
        _chip('主角', _allChars.where((c) => c.role == '主角').length, Colors.amber),
        _chip('配角', _allChars.where((c) => c.role == '配角' || c.role == '重要配角').length, Colors.teal),
        _chip('反派', _allChars.where((c) => c.role == '反派').length, Colors.red),
      ]),
    );
  }

  Widget _chip(String label, int count, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withAlpha(80))),
        child: Text('$label: $count',
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
      );

  Widget _card(NovelCharacter c) => Card(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: _roleColor(c.role).withAlpha(80))),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showDetail(c),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (c.imagePath.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Image.file(
                    File(c.imagePath),
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              Row(children: [
                CircleAvatar(
                    radius: 20,
                    backgroundColor: _roleColor(c.role).withAlpha(40),
                    child: Text(c.name.isNotEmpty ? c.name[0] : '?',
                        style: TextStyle(fontWeight: FontWeight.bold, color: _roleColor(c.role)))),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  Text('${c.gender} · ${c.role}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ])),
                InkWell(
                  onTap: () => _showItemInspiration(c),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(color: Colors.orange.withAlpha(20), borderRadius: BorderRadius.circular(4)),
                    child: const Icon(Icons.lightbulb, size: 16, color: Colors.orange),
                  ),
                ),
                PopupMenuButton<String>(
                    iconSize: 18,
                    onSelected: (a) {
                      if (a == 'edit') _edit(existing: c);
                      if (a == 'delete') _delete(c);
                    },
                    itemBuilder: (ctx) => [
                          const PopupMenuItem(value: 'edit', child: Text('编辑')),
                          const PopupMenuItem(
                              value: 'delete',
                              child: Text('删除', style: TextStyle(color: Colors.red))),
                        ]),
              ]),
              if (c.faction.isNotEmpty)
                Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(children: [
                      Icon(Icons.flag, size: 13, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Expanded(child: Text(c.faction, style: TextStyle(fontSize: 12, color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ])),
              const Spacer(),
              if (c.personality.isNotEmpty)
                Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: c.personality
                        .take(4)
                        .map((p) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(6)),
                            child: Text(p, style: const TextStyle(fontSize: 10))))
                        .toList()),
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.people, size: 13, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text('关系 ${c.relationships.length}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                const Spacer(),
                if (c.firstChapter > 0)
                  Text('首出第${c.firstChapter}章',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ]),
            ]),
          ),
        ),
      );

  void _showDetail(NovelCharacter c) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          CircleAvatar(
              radius: 16,
              backgroundColor: _roleColor(c.role).withAlpha(40),
              child: Text(c.name[0],
                  style: TextStyle(color: _roleColor(c.role), fontWeight: FontWeight.bold))),
          const SizedBox(width: 10),
          Text(c.name),
          const Spacer(),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: _roleColor(c.role).withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _roleColor(c.role).withAlpha(80))),
              child: Text(c.role,
                  style: TextStyle(fontSize: 11, color: _roleColor(c.role)))),
        ]),
        content: SingleChildScrollView(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _infoRow('性别', c.gender),
                _infoRow('年龄', c.age),
                _infoRow('势力', c.faction),
                if (c.appearance.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('外貌', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(c.appearance, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                ],
                if (c.personality.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text('性格', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                  const SizedBox(height: 4),
                  Wrap(
                      spacing: 6,
                      children: c.personality
                          .map((p) => Chip(
                              label: Text(p, style: const TextStyle(fontSize: 11)),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact))
                          .toList()),
                ],
                if (c.abilities.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text('能力', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                  const SizedBox(height: 4),
                  Wrap(
                      spacing: 6,
                      children: c.abilities
                          .map((a) => Chip(
                              label: Text(a, style: const TextStyle(fontSize: 11)),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              backgroundColor: Colors.teal[50]))
                          .toList()),
                ],
                if (c.relationships.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text('关系网络', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                  const SizedBox(height: 4),
                  ...c.relationships.map((r) => Card(
                      color: Colors.grey[50],
                      margin: const EdgeInsets.only(bottom: 4),
                      child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(children: [
                            Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(6)),
                                child: Text(r.type, style: const TextStyle(fontSize: 11))),
                            const SizedBox(width: 8),
                            Text('→ ${r.targetName}',
                                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                            if (r.description.isNotEmpty)
                              Text(' — ${r.description}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                          ])))),
                ],
                if (c.firstChapter > 0) ...[
                  const SizedBox(height: 10),
                  _infoRow('首次出场', '第${c.firstChapter}章'),
                ],
                if (c.currentStatus.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _infoRow('当前状态', c.currentStatus),
                ],
                if (c.notes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _infoRow('备注', c.notes),
                ],
              ]),
        ),
        actions: [
          TextButton(
              onPressed: () { Navigator.pop(ctx); _edit(existing: c); },
              child: const Text('编辑')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          SizedBox(width: 60, child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
          Expanded(child: Text(value.isNotEmpty ? value : '-', style: const TextStyle(fontSize: 13))),
        ]),
      );
}

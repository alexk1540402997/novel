import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/services/context_memory_service.dart';
import '../pages/novel_architecture_page.dart'; // SelectedNovelProvider

class MemoryOverviewPage extends StatefulWidget {
  const MemoryOverviewPage({super.key});
  @override
  State<MemoryOverviewPage> createState() => _MemoryOverviewPageState();
}

class _MemoryOverviewPageState extends State<MemoryOverviewPage> {
  final _svc = ContextMemoryService();
  List<ChapterMemory> _memories = [];
  bool _loading = false;
  String? _novel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    final n = context.read<SelectedNovelProvider>().selectedNovel;
    if (n != _novel) { _novel = n; if (n != null) _load(); }
  }

  Future<void> _load() async {
    if (_novel == null) return;
    setState(() => _loading = true);
    await _svc.load(_novel!);
    setState(() { _memories = _svc.allMemories; _loading = false; });
  }

  Future<void> _editChapterMemory(int chapterNum) async {
    final existing = _svc.getChapter(chapterNum);
    final cm = existing ?? ChapterMemory(chapterNumber: chapterNum);
    String summary = cm.summary;
    String charStr = cm.charactersAppeared.join('、');
    String worldStr = cm.worldSettingsUsed.join('、');
    String eventStr = cm.keyEvents.join('、');
    int wc = cm.wordCount;

    final r = await showDialog<ChapterMemory>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
        title: Text('第$chapterNum章 记忆编辑'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(decoration: const InputDecoration(labelText:'章节摘要',border:OutlineInputBorder(),isDense:true), controller:TextEditingController(text:summary), onChanged:(v)=>summary=v, maxLines:3),
          const SizedBox(height:10),
          TextField(decoration: const InputDecoration(labelText:'出场角色(、分隔)',border:OutlineInputBorder(),isDense:true), controller:TextEditingController(text:charStr), onChanged:(v)=>charStr=v),
          const SizedBox(height:10),
          TextField(decoration: const InputDecoration(labelText:'涉及世界观设定(、分隔)',border:OutlineInputBorder(),isDense:true), controller:TextEditingController(text:worldStr), onChanged:(v)=>worldStr=v),
          const SizedBox(height:10),
          TextField(decoration: const InputDecoration(labelText:'关键事件(、分隔)',border:OutlineInputBorder(),isDense:true), controller:TextEditingController(text:eventStr), onChanged:(v)=>eventStr=v),
          const SizedBox(height:10),
          TextField(decoration: const InputDecoration(labelText:'字数',border:OutlineInputBorder(),isDense:true), controller:TextEditingController(text:wc>0?wc.toString():''), onChanged:(v)=>wc=int.tryParse(v)??0, keyboardType:TextInputType.number),
        ])),
        actions: [
          TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('取消')),
          FilledButton(onPressed:(){
            final m = ChapterMemory(chapterNumber:chapterNum, summary:summary,
              charactersAppeared:charStr.split('、').map((e)=>e.trim()).where((e)=>e.isNotEmpty).toList(),
              worldSettingsUsed:worldStr.split('、').map((e)=>e.trim()).where((e)=>e.isNotEmpty).toList(),
              keyEvents:eventStr.split('、').map((e)=>e.trim()).where((e)=>e.isNotEmpty).toList(),
              wordCount:wc);
            Navigator.pop(ctx, m);
          }, child: const Text('保存')),
        ],
      )),
    );
    if (r != null) { await _svc.updateChapter(r); _load(); }
  }

  Future<void> _deleteChapter(int cn) async {
    await _svc.removeChapter(cn); _load();
  }

  @override
  Widget build(BuildContext context) {
    final n = context.watch<SelectedNovelProvider>().selectedNovel;
    if (n != _novel) WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    if (_novel == null) return const Center(child: Text('请先选择一部小说'));

    final twc = _svc.totalWordCount;
    final allChars = _svc.allCharacters;

    return Column(children: [
      // 总览卡片
      Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.teal[700]!, Colors.teal[500]!]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('🧠 写作记忆', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('${_memories.length}章 · 约${twc}字 · ${allChars.length}个角色',
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ])),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 36),
            onPressed: () => _editChapterMemory(_memories.length + 1),
            tooltip: '添加章节记忆',
          ),
        ]),
      ),
      // 全角色标签
      if (allChars.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(spacing: 6, runSpacing: 4, children: allChars
              .map((c) => Chip(label: Text(c, style: const TextStyle(fontSize: 11)),
                  avatar: const Icon(Icons.person, size: 14), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, visualDensity: VisualDensity.compact))
              .toList()),
        ),
      const SizedBox(height: 8),
      // 章节记忆列表
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _memories.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.memory, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    const Text('记忆库为空', style: TextStyle(color: Colors.grey)),
                    const Text('点击上方+号添加章节记忆', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ]))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: _memories.length,
                    itemBuilder: (ctx, i) {
                      final m = _memories[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _editChapterMemory(m.chapterNumber),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.teal[100], borderRadius: BorderRadius.circular(8)),
                                    child: Text('第${m.chapterNumber}章', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.teal[800]))),
                                const SizedBox(width: 10),
                                Text('${m.wordCount}字', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                const Spacer(),
                                IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red), onPressed: () => _deleteChapter(m.chapterNumber), constraints: const BoxConstraints()),
                              ]),
                              if (m.summary.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(m.summary, style: TextStyle(fontSize: 13, color: Colors.grey[800]), maxLines: 3, overflow: TextOverflow.ellipsis),
                              ],
                              if (m.charactersAppeared.isNotEmpty || m.worldSettingsUsed.isNotEmpty || m.keyEvents.isNotEmpty)
                                Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Wrap(spacing: 4, runSpacing: 2, children: [
                                      ...m.charactersAppeared.map((c) => Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(4)), child: Text(c, style: TextStyle(fontSize: 10, color: Colors.blue[800])))),
                                      ...m.worldSettingsUsed.map((w) => Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: Colors.purple[50], borderRadius: BorderRadius.circular(4)), child: Text(w, style: TextStyle(fontSize: 10, color: Colors.purple[800])))),
                                      ...m.keyEvents.map((e) => Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(4)), child: Text(e, style: TextStyle(fontSize: 10, color: Colors.orange[800])))),
                                    ])),
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    ]);
  }
}

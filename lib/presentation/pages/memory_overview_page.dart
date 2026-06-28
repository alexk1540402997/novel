import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/datasources/local/novel_file_service.dart';
import '../../domain/services/context_memory_service.dart';
import '../../domain/usecases/llm_usecase.dart';
import '../../utils/config_service.dart';
import '../pages/novel_architecture_page.dart'; // SelectedNovelProvider

class MemoryOverviewPage extends StatefulWidget {
  const MemoryOverviewPage({super.key});
  @override
  State<MemoryOverviewPage> createState() => _MemoryOverviewPageState();
}

class _MemoryOverviewPageState extends State<MemoryOverviewPage> {
  final _svc = ContextMemoryService();
  final _fileSvc = NovelFileService();
  List<ChapterMemory> _memories = [];
  List<int> _chapterNums = [];
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
    final nums = await _fileSvc.getChapterNumbers(_novel!);
    setState(() { _memories = _svc.allMemories; _chapterNums = nums; _loading = false; });
  }

  int _editChapterNum = 1; // 默认编辑的章节号

  Future<void> _editChapterMemory(int chapterNum) async {
    final existing = _svc.getChapter(chapterNum);
    final cm = existing ?? ChapterMemory(chapterNumber: chapterNum);
    String summary = cm.summary;
    String charStr = cm.charactersAppeared.join('、');
    String worldStr = cm.worldSettingsUsed.join('、');
    String eventStr = cm.keyEvents.join('、');
    String userNotes = cm.userNotes;
    int wc = cm.wordCount;
    int selectedChapter = chapterNum;
    bool _aiLoading = false;

    final r = await showDialog<ChapterMemory>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.memory, color: Colors.teal, size: 20),
          const SizedBox(width: 8),
          const Text('写作记忆编辑', style: TextStyle(fontSize: 16)),
        ]),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // 章节选择器
          Row(children: [
            const Text('选择章节: ', style: TextStyle(fontSize: 13)),
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _chapterNums.contains(selectedChapter) ? selectedChapter : null,
                hint: Text('第$selectedChapter章', style: const TextStyle(fontSize: 13)),
                decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                items: _chapterNums.map((n) => DropdownMenuItem(value: n, child: Text('第$n章', style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setD(() {
                    selectedChapter = v;
                    final exist = _svc.getChapter(v);
                    if (exist != null) {
                      summary = exist.summary;
                      charStr = exist.charactersAppeared.join('、');
                      worldStr = exist.worldSettingsUsed.join('、');
                      eventStr = exist.keyEvents.join('、');
                      wc = exist.wordCount;
                    } else {
                      summary = ''; charStr = ''; worldStr = ''; eventStr = ''; wc = 0;
                    }
                  });
                },
              ),
            ),
          ]),
          const SizedBox(height: 8),
          // AI归纳按钮
          OutlinedButton.icon(
            onPressed: _aiLoading ? null : () async {
              setD(() => _aiLoading = true);
              try {
                // 尝试读取章节内容并用AI归纳
                final chContent = await _fileSvc.readChapter(_novel!, selectedChapter);
                if (chContent == null || chContent.trim().isEmpty) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('该章节无内容')));
                  }
                  setD(() => _aiLoading = false);
                  return;
                }
                final config = ConfigService().getAll();
                final llmName = config?['choose_configs']?['final_chapter_llm'] ?? 'Claude Sonnet 4.6';
                final prompt = '''请分析以下小说章节内容，提取关键信息用于写作记忆：

$chContent

请以JSON格式返回（只返回JSON，不返回其他内容）：
{
  "summary": "章节摘要（100字以内）",
  "characters": ["出场角色1", "出场角色2"],
  "worldSettings": ["涉及的世界观设定"],
  "keyEvents": ["关键事件1", "关键事件2"],
  "wordCount": 章节字数
}''';
                final llm = LLMUseCase();
                final result = await llm.generateText(prompt, llmName);
                // 简易JSON解析
                try {
                  final json = jsonDecode(result);
                  setD(() {
                    summary = json['summary'] ?? '';
                    charStr = (json['characters'] as List?)?.join('、') ?? '';
                    worldStr = (json['worldSettings'] as List?)?.join('、') ?? '';
                    eventStr = (json['keyEvents'] as List?)?.join('、') ?? '';
                    wc = json['wordCount'] ?? chContent.length;
                  });
                } catch (_) {
                  // 解析失败，使用原始内容作为摘要
                  setD(() {
                    summary = chContent.length > 200 ? '${chContent.substring(0, 200)}...' : chContent;
                    wc = chContent.length;
                  });
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('AI归纳失败: $e'), backgroundColor: Colors.red));
                }
              }
              setD(() => _aiLoading = false);
            },
            icon: _aiLoading ? const SizedBox(width:14,height:14,child:CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.auto_awesome, size: 16),
            label: Text(_aiLoading ? '归纳中...' : 'AI智能归纳'),
          ),
          const Divider(),
          TextField(decoration: const InputDecoration(labelText:'章节摘要',border:OutlineInputBorder(),isDense:true), controller:TextEditingController(text:summary), onChanged:(v)=>summary=v, maxLines:3),
          const SizedBox(height:10),
          TextField(decoration: const InputDecoration(labelText:'出场角色(、分隔)',border:OutlineInputBorder(),isDense:true), controller:TextEditingController(text:charStr), onChanged:(v)=>charStr=v),
          const SizedBox(height:10),
          TextField(decoration: const InputDecoration(labelText:'涉及世界观设定(、分隔)',border:OutlineInputBorder(),isDense:true), controller:TextEditingController(text:worldStr), onChanged:(v)=>worldStr=v),
          const SizedBox(height:10),
          TextField(decoration: const InputDecoration(labelText:'关键事件(、分隔)',border:OutlineInputBorder(),isDense:true), controller:TextEditingController(text:eventStr), onChanged:(v)=>eventStr=v),
          const SizedBox(height:10),
          TextField(decoration: const InputDecoration(labelText:'字数',border:OutlineInputBorder(),isDense:true), controller:TextEditingController(text:wc>0?wc.toString():''), onChanged:(v)=>wc=int.tryParse(v)??0, keyboardType:TextInputType.number),
          const SizedBox(height:10),
          TextField(decoration: const InputDecoration(labelText:'手动备注（补充AI遗漏的要点）',border:OutlineInputBorder(),isDense:true, hintText:'在此补充任何遗漏的关键内容...'), controller:TextEditingController(text:userNotes), onChanged:(v)=>userNotes=v, maxLines:4),
        ])),
        actions: [
          TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('取消')),
          FilledButton(onPressed:(){
            final m = ChapterMemory(chapterNumber:selectedChapter, summary:summary,
              charactersAppeared:charStr.split('、').map((e)=>e.trim()).where((e)=>e.isNotEmpty).toList(),
              worldSettingsUsed:worldStr.split('、').map((e)=>e.trim()).where((e)=>e.isNotEmpty).toList(),
              keyEvents:eventStr.split('、').map((e)=>e.trim()).where((e)=>e.isNotEmpty).toList(),
              wordCount:wc, userNotes:userNotes);
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

  bool _guideBannerExpanded = false;

  /// 始终显示在列表上方的引导提示条（可收起）
  Widget _buildGuideBanner() {
    if (_memories.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Card(
        margin: EdgeInsets.zero,
        color: Colors.teal[50],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: InkWell(
          onTap: () => setState(() => _guideBannerExpanded = !_guideBannerExpanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.info_outline, size: 16, color: Colors.teal[700]),
                const SizedBox(width: 6),
                Text('写作记忆提示', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.teal[700])),
                const Spacer(),
                Icon(_guideBannerExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 16, color: Colors.teal[700]),
              ]),
              if (_guideBannerExpanded) ...[
                const SizedBox(height: 8),
                Text('点击任意记忆卡片可编辑 → 选择章节 → 点击「AI智能归纳」自动分析章节内容 → 手动补充修改 → 保存',
                  style: TextStyle(fontSize: 11, color: Colors.teal[600], height: 1.5)),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyGuide() => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(children: [
      Icon(Icons.memory, size: 56, color: Colors.teal[300]),
      const SizedBox(height: 16),
      const Text('写作记忆库', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text('帮助AI记住前文内容，自动为续写提供上下文',
        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 32),
      // 功能介绍卡片
      _introCard(
        Icons.psychology, '什么是写作记忆？',
        '写作记忆是每章的核心信息摘要，包括情节概要、出场角色、涉及的世界观设定和关键事件。'
            '当你使用AI续写时，系统会自动提取相关章节的记忆作为上下文，让AI写出的内容更连贯、角色性格更一致。',
        Colors.teal,
      ),
      const SizedBox(height: 12),
      _introCard(
        Icons.auto_awesome, '与AI写作如何联动？',
        '在「章节写作」页面点击「大纲→正文」进行AI生成时，系统会自动查找最近5章的记忆作为参考。'
            '记忆越详细，AI生成质量越高。建议每写完一章就补充该章的记忆。',
        Colors.blue,
      ),
      const SizedBox(height: 12),
      _introCard(
        Icons.tips_and_updates, '如何开始？',
        '1. 先完成至少一章的写作\n2. 点击右上角 + 按钮\n3. 填写章节摘要、出场角色、关键事件\n4. 后续AI续写会自动引用这些记忆',
        Colors.orange,
      ),
      const SizedBox(height: 24),
      FilledButton.icon(
        onPressed: () => _editChapterMemory(_chapterNums.isNotEmpty ? _chapterNums.first : 1),
        icon: const Icon(Icons.auto_awesome, size: 18),
        label: const Text('进入记忆库'),
      ),
    ]),
  );

  Widget _introCard(IconData icon, String title, String desc, Color color) => Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: color)),
          const SizedBox(height: 6),
          Text(desc, style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.5)),
        ])),
      ]),
    ),
  );

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
      // 可收起的引导提示（始终显示在列表上方）
      _buildGuideBanner(),
      // 章节记忆列表
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _memories.isEmpty
                ? _buildEmptyGuide()
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

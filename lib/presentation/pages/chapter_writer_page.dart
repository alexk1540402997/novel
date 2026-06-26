import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/datasources/local/novel_file_service.dart';
import '../../domain/services/context_memory_service.dart';
import '../../domain/usecases/llm_usecase.dart';
import '../../utils/config_service.dart';
import '../pages/novel_architecture_page.dart';

class ChapterWriterPage extends StatefulWidget {
  const ChapterWriterPage({super.key});
  @override
  State<ChapterWriterPage> createState() => _ChapterWriterPageState();
}

class _ChapterWriterPageState extends State<ChapterWriterPage> {
  final _fileSvc = NovelFileService();
  final _memorySvc = ContextMemoryService();
  final _textCtrl = TextEditingController();
  final _outlineCtrl = TextEditingController();
  String? _novel;
  List<int> _chapterNums = [];
  int? _currentChapter;
  String _chapterContent = '';
  bool _loading = false;
  bool _generating = false;
  bool _correcting = false;
  String? _generatedText;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    final n = context.read<SelectedNovelProvider>().selectedNovel;
    if (n != _novel) { _novel = n; if (n != null) { _memorySvc.load(n); _loadChapters(); } }
  }

  Future<void> _loadChapters() async {
    if (_novel == null) return;
    setState(() => _loading = true);
    final nums = await _fileSvc.getChapterNumbers(_novel!);
    setState(() { _chapterNums = nums; _loading = false; });
  }

  Future<void> _selectChapter(int num) async {
    if (_novel == null) return;
    // 保存当前章节
    if (_currentChapter != null && _textCtrl.text != _chapterContent) {
      await _fileSvc.saveChapter(_novel!, _currentChapter!, _textCtrl.text);
    }
    final content = await _fileSvc.readChapter(_novel!, num);
    setState(() {
      _currentChapter = num;
      _chapterContent = content ?? '';
      _textCtrl.text = _chapterContent;
      _generatedText = null;
    });
  }

  Future<void> _addChapter() async {
    if (_novel == null) return;
    final next = _chapterNums.isEmpty ? 1 : (_chapterNums.last + 1);
    await _fileSvc.saveChapter(_novel!, next, '');
    await _loadChapters();
    _selectChapter(next);
  }

  Future<void> _saveCurrent() async {
    if (_novel == null || _currentChapter == null) return;
    await _fileSvc.saveChapter(_novel!, _currentChapter!, _textCtrl.text);
    setState(() => _chapterContent = _textCtrl.text);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('第${_currentChapter}章已保存'), backgroundColor: Colors.green, duration: const Duration(seconds: 1)),
    );
  }

  // 章节模式：大纲→正文
  Future<void> _generateFromOutline() async {
    if (_novel == null || _currentChapter == null) return;
    final outline = _outlineCtrl.text.trim();
    if (outline.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先在右侧输入本章大纲'), backgroundColor: Colors.red));
      return;
    }
    setState(() => _generating = true);

    try {
      final config = ConfigService().getAll();
      final llmName = config?['choose_configs']?['final_chapter_llm'] ?? 'Claude Sonnet 4.6';
      final contextCtx = _memorySvc.buildContinuationContext(_currentChapter!, lookback: 5);

      final prompt = '''你是一位专业网文作家。请根据以下大纲撰写第${_currentChapter}章正文。

$contextCtx

=== 本章大纲 ===
$outline

=== 写作要求 ===
1. 自然衔接前文内容，保持角色性格和叙事风格一致
2. 本章字数约3000-5000字
3. 要有具体的场景描写、对话、动作
4. 语言流畅、避免AI味（减少"然而""因此""于是"等过度连接词）
5. 在本章末尾留下悬念或伏笔，吸引读者继续阅读

请直接输出章节正文，不需要额外解释。''';

      final llm = LLMUseCase();
      final result = await llm.generateText(prompt, llmName);
      setState(() { _generatedText = result; _generating = false; });
    } catch (e) {
      setState(() => _generating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('生成失败: $e'), backgroundColor: Colors.red));
    }
  }

  void _applyGenerated() {
    if (_generatedText == null) return;
    final current = _textCtrl.text;
    _textCtrl.text = current.isEmpty ? _generatedText! : '$current\n\n$_generatedText';
    setState(() => _generatedText = null);
  }

  // 错字矫正
  Future<void> _checkTypos() async {
    final text = _textCtrl.text;
    if (text.trim().isEmpty) return;
    setState(() => _correcting = true);

    try {
      // 本地常见错别字检查
      final corrections = _localTypoCheck(text);
      if (corrections.isNotEmpty) {
        _showCorrectionDialog(corrections);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('本地检查未发现常见错别字 ✅'), backgroundColor: Colors.green));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('检查失败: $e'), backgroundColor: Colors.red));
    }
    setState(() => _correcting = false);
  }

  List<({String wrong, String correct, int position})> _localTypoCheck(String text) {
    // 常见错别字词库
    final typoDict = <String, String>{
      '在见': '再见', '已后': '以后', '以经': '已经',
      '的却': '的确', '道底': '到底', '即然': '既然', '既使': '即使',
      '坚苦': '艰苦', '决对': '绝对', '克苦': '刻苦', '连系': '联系',
      '了望': '瞭望', '另人': '令人', '秘蜜': '秘密', '名子': '名字',
      '那怕': '哪怕', '偶而': '偶尔', '佩合': '配合', '期实': '其实',
      '清淅': '清晰', '缺定': '确定', '刃具': '忍具', '身分': '身份',
      '什幺': '什么', '事绩': '事迹', '收寻': '搜寻', '舒发': '抒发',
      '署假': '暑假', '虽便': '随便', '题纲': '提纲', '忘想': '妄想',
      '希奇': '稀奇', '希有': '稀有', '相象': '想象', '消毁': '销毁',
      '型状': '形状', '修息': '休息', '讯速': '迅速', '一至': '一致',
      '义论': '议论', '影象': '影像', '尤如': '犹如', '於事': '于是',
      '原故': '缘故', '造形': '造型', '知到': '知道',
      '重来': '从来', '自毫': '自豪', '尊守': '遵守', '坐位': '座位',
      '复盖': '覆盖', '恢心': '灰心', '会报': '汇报', '积积': '积极',
      '计术': '技术', '记念': '纪念', '既将': '即将', '坚难': '艰难',
      '结素': '结束', '经长': '经常', '决择': '抉择', '开消': '开销',
      '空闭': '空闲', '浪废': '浪费', '理采': '理睬',
      '联洛': '联络', '买责': '埋折', '曼延': '蔓延', '煤介': '媒介',
      '迷语': '谜语', '摩仿': '模仿', '年青': '年轻', '判逆': '叛逆',
      '期骗': '欺骗', '起原': '起源', '气慨': '气概', '迁涉': '牵扯',
      '前题': '前提', '浅漏': '浅陋', '歉虚': '谦虚', '青萃': '清脆',
      '轻篾': '轻蔑', '权立': '权力', '缺泛': '缺乏', '溶恰': '融洽',
      '溶岩': '熔岩', '如罪': '认罪', '撒慌': '撒谎', '杀戳': '杀戮',
      '赏试': '尝试', '伸请': '申请', '生辟': '生僻', '失言': '食言',
      '史无前列': '史无前例', '世外桃园': '世外桃源', '事得其反': '适得其反',
      '收俭': '收敛', '守猎': '狩猎', '舒援': '舒缓', '署光': '曙光',
      '衰若': '衰弱', '水笼头': '水龙头', '所然': '虽然', '锁碎': '琐碎',
      '唐塞': '搪塞', '提练': '提炼', '天之娇子': '天之骄子', '挑畔': '挑衅',
      '突如奇来': '突如其来', '推祟': '推崇', '脱颍而出': '脱颖而出',
      '万赖俱寂': '万籁俱寂', '亡羊补牢': '亡羊补牢', '望其项背': '望其项背',
      '危胁': '威胁', '为非作夕': '为非作歹', '惟命是从': '唯命是从',
      '萎糜': '萎靡', '温磐': '温馨', '文诌诌': '文绉绉', '闻名遐尔': '闻名遐迩',
      '污告': '诬告', '无地放矢': '无的放矢', '无计于事': '无济于事',
      '无坚不催': '无坚不摧', '无礼取闹': '无理取闹', '无原无故': '无缘无故',
      '嘻戏': '嬉戏', '喜笑眼开': '喜笑颜开',
      '暇想': '遐想', '闲熟': '娴熟', '显郝': '显赫', '相题并论': '相提并论',
      '消声匿迹': '销声匿迹', '箫洒': '潇洒', '小心奕奕': '小心翼翼',
      '心恢意冷': '心灰意冷', '心急火撩': '心急火燎', '兴高彩烈': '兴高采烈',
      '雄心壮志': '雄心壮志', '虚渡': '虚度',
      '虚寒问暖': '嘘寒问暖', '喧哗': '喧哗', '悬梁刺骨': '悬梁刺股',
      '寻规蹈矩': '循规蹈矩', '训炼': '训练', '严利': '严厉',
      '眼花了乱': '眼花缭乱', '阳奉阴为': '阳奉阴违', '一酬莫展': '一筹莫展',
      '一股作气': '一鼓作气', '一獗不振': '一蹶不振', '一诺千斤': '一诺千金',
      '一如即往': '一如既往', '一视同人': '一视同仁', '一张一驰': '一张一弛',
      '遗害': '贻害', '以逸代劳': '以逸待劳', '义愤填赝': '义愤填膺',
      '因材失教': '因材施教', '阴狸': '阴霾', '引亢高歌': '引吭高歌',
      '英雄气慨': '英雄气概', '英雄倍出': '英雄辈出', '永往直前': '勇往直前',
      '有持无恐': '有恃无恐', '予其': '与其', '语无轮次': '语无伦次',
      '欲盖弥章': '欲盖弥彰', '原形必露': '原形毕露', '怨天忧人': '怨天尤人',
      '越趄代庖': '越俎代庖', '云云众生': '芸芸众生', '运筹惟幄': '运筹帷幄',
      '再劫难逃': '在劫难逃', '责无旁代': '责无旁贷', '瞻养': '赡养',
      '张慌失措': '张皇失措', '招摇装骗': '招摇撞骗', '真知卓见': '真知灼见',
      '阵定自若': '镇定自若', '正经危坐': '正襟危坐', '直接了当': '直截了当',
      '指高气扬': '趾高气扬', '至理明言': '至理名言', '治丝益纷': '治丝益棼',
      '重蹈复辙': '重蹈覆辙', '重山峻岭': '崇山峻岭', '珠联壁合': '珠联璧合',
      '专心至志': '专心致志', '追本朔源': '追本溯源', '谆谆告戒': '谆谆告诫',
      '自抱自弃': '自暴自弃', '自吹自雷': '自吹自擂', '自名得意': '自鸣得意',
      '自园其说': '自圆其说', '坐无虚席': '座无虚席',
      '的': '地', // 可能的的地得混用标记
    };

    final results = <({String wrong, String correct, int position})>[];
    for (final entry in typoDict.entries) {
      int idx = 0;
      while ((idx = text.indexOf(entry.key, idx)) != -1) {
        results.add((wrong: entry.key, correct: entry.value, position: idx));
        idx += entry.key.length;
      }
    }
    results.sort((a, b) => a.position.compareTo(b.position));
    return results;
  }

  void _showCorrectionDialog(List<({String wrong, String correct, int position})> corrections) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text('发现 ${corrections.length} 处疑似错别字'),
      content: SizedBox(width: double.maxFinite, child: ListView.builder(
        shrinkWrap: true,
        itemCount: corrections.length,
        itemBuilder: (ctx, i) {
          final c = corrections[i];
          final contextStart = c.position > 10 ? c.position - 10 : 0;
          final contextEnd = (c.position + c.wrong.length + 10) > _textCtrl.text.length ? _textCtrl.text.length : c.position + c.wrong.length + 10;
          final ctxText = _textCtrl.text.substring(contextStart, contextEnd).replaceAll('\n', ' ');
          return ListTile(
            dense: true,
            leading: const Icon(Icons.error_outline, color: Colors.orange),
            title: RichText(text: TextSpan(children: [
              if (contextStart > 0) const TextSpan(text: '…', style: TextStyle(color: Colors.grey)),
              TextSpan(text: c.wrong, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, decoration: TextDecoration.lineThrough)),
              TextSpan(text: ' → ', style: TextStyle(color: Colors.grey[600])),
              TextSpan(text: c.correct, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              if (contextEnd < _textCtrl.text.length) const TextSpan(text: '…', style: TextStyle(color: Colors.grey)),
            ])),
            subtitle: Text('上文: ...$ctxText...', style: const TextStyle(fontSize: 11)),
            onTap: () {
              // 替换错字
              final newText = _textCtrl.text.replaceRange(c.position, c.position + c.wrong.length, c.correct);
              _textCtrl.text = newText;
              Navigator.pop(ctx);
            },
          );
        },
      )),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
        FilledButton(onPressed: () {
          // 一键全部替换
          String newText = _textCtrl.text;
          // 从后往前替换避免位置偏移
          final sorted = List.from(corrections)..sort((a,b)=>b.position.compareTo(a.position));
          for (final c in sorted) {
            newText = newText.replaceRange(c.position, c.position + c.wrong.length, c.correct);
          }
          _textCtrl.text = newText;
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已替换 ${corrections.length} 处错别字'), backgroundColor: Colors.green));
        }, child: const Text('全部替换')),
      ],
    ));
  }

  @override
  void dispose() {
    if (_currentChapter != null && _textCtrl.text != _chapterContent) {
      _fileSvc.saveChapter(_novel!, _currentChapter!, _textCtrl.text);
    }
    _textCtrl.dispose();
    _outlineCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = context.watch<SelectedNovelProvider>().selectedNovel;
    if (n != _novel) WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    if (_novel == null) return const Center(child: Text('请先选择一部小说'));

    return Row(children: [
      // 左侧：章节列表
      SizedBox(
        width: 180,
        child: _loading ? const Center(child: CircularProgressIndicator()) : Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                onPressed: _addChapter, icon: const Icon(Icons.add, size: 16),
                label: const Text('新章节'), style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 36)),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _chapterNums.length,
                itemBuilder: (ctx, i) {
                  final num = _chapterNums[i];
                  final isSelected = _currentChapter == num;
                  return ListTile(
                    selected: isSelected,
                    dense: true,
                    title: Text('第$num章', style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    onTap: () => _selectChapter(num),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      const VerticalDivider(width: 1),
      // 中间：编辑器
      Expanded(
        flex: 3,
        child: Column(children: [
          // 工具栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.grey[50], border: const Border(bottom: BorderSide(color: Color(0xFFE0E0E0)))),
            child: Row(children: [
              if (_currentChapter != null) Text('第$_currentChapter章', style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.save), onPressed: _saveCurrent, tooltip: '保存 (Ctrl+S)', iconSize: 20),
              IconButton(icon: _correcting ? const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.spellcheck), onPressed: _correcting ? null : _checkTypos, tooltip: '错字检查', iconSize: 20),
            ]),
          ),
          Expanded(
            child: TextField(
              controller: _textCtrl,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(fontSize: 15, height: 1.8, fontFamily: 'serif'),
              decoration: const InputDecoration(
                hintText: '在此撰写章节正文...\n\n提示：先写大纲→点AI生成→获得初稿→手动润色',
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
            ),
          ),
        ]),
      ),
      const VerticalDivider(width: 1),
      // 右侧：AI协作面板
      Expanded(
        flex: 2,
        child: Container(
          color: Colors.grey[50],
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey[100], border: const Border(bottom: BorderSide(color: Color(0xFFE0E0E0)))),
              child: Row(children: [
                const Icon(Icons.auto_awesome, size: 18, color: Colors.teal),
                const SizedBox(width: 8),
                const Text('AI章节生成', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              ]),
            ),
            Expanded(
              child: ListView(padding: const EdgeInsets.all(12), children: [
                const Text('📋 本章大纲', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: _outlineCtrl,
                  maxLines: 6,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: '输入本章大纲要点：\n- 开场场景\n- 主要事件\n- 角色互动\n- 结尾悬念',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true, contentPadding: const EdgeInsets.all(10),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _generating ? null : _generateFromOutline,
                    icon: _generating ? const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)) : const Icon(Icons.auto_awesome, size: 16),
                    label: Text(_generating ? 'AI生成中...' : '大纲→正文'),
                    style: FilledButton.styleFrom(backgroundColor: Colors.teal),
                  ),
                ),
                if (_generatedText != null) ...[
                  const SizedBox(height: 16),
                  Row(children: [
                    const Text('✨ 生成结果', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                    const Spacer(),
                    TextButton(onPressed: _applyGenerated, child: const Text('应用到正文')),
                    TextButton(onPressed: ()=>setState(()=>_generatedText=null), child: const Text('丢弃', style: TextStyle(color: Colors.red))),
                  ]),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.teal[100]!)),
                    child: SelectableText(_generatedText!, style: const TextStyle(fontSize: 13, height: 1.6)),
                  ),
                ],
                const Divider(height: 24),
                Text('💡 写作提示', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.grey[700])),
                const SizedBox(height: 8),
                _tip('大纲越详细，AI生成质量越高'),
                _tip('建议每章3000-5000字为佳'),
                _tip('生成后再手动润色去AI味'),
                _tip('点击🔍错字检查可自动发现常见错误'),
              ]),
            ),
          ]),
        ),
      ),
    ]);
  }

  Widget _tip(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text('• $text', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
  );
}

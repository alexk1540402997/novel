import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/datasources/local/novel_file_service.dart';
import '../../domain/services/context_memory_service.dart';
import '../../domain/services/image_generation_service.dart';
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
  bool _polishing = false;
  bool _aiPanelExpanded = true; // AI面板展开/收起
  String? _generatedText;
  double _editorFontSize = 15; // 编辑器字体大小，可从设置调节

  @override
  void initState() {
    super.initState();
    _loadEditorFontSize();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    final n = context.read<SelectedNovelProvider>().selectedNovel;
    if (n != _novel) { _novel = n; if (n != null) { _memorySvc.load(n); _loadChapters(); } }
  }

  /// 从设置中加载编辑器字体大小
  void _loadEditorFontSize() {
    final config = ConfigService().getAll();
    final saved = (config?['editor_font_size'] as num?)?.toDouble();
    if (saved != null && saved >= 12 && saved <= 24) {
      _editorFontSize = saved;
    }
  }

  Future<void> _loadChapters() async {
    if (_novel == null) return;
    setState(() => _loading = true);
    final nums = await _fileSvc.getChapterNumbers(_novel!);
    setState(() { _chapterNums = nums; _loading = false; });
    // 自动选择第一个章节（如果没有当前选中的章节）
    if (_currentChapter == null && nums.isNotEmpty) {
      _selectChapter(nums.first);
    }
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
    // 自动保存
    _saveCurrent();
  }

  /// AI润色选中的文本
  Future<void> _polishSelectedText() async {
    final selection = _textCtrl.selection;
    if (!selection.isValid || selection.isCollapsed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选中要润色的文字'), backgroundColor: Colors.red),
      );
      return;
    }
    final selectedText = selection.textInside(_textCtrl.text);
    if (selectedText.trim().isEmpty) return;

    setState(() => _polishing = true);
    try {
      final config = ConfigService().getAll();
      final llmName = config?['choose_configs']?['final_chapter_llm'] ?? 'Claude Sonnet 4.6';
      final prompt = '请润色以下中文小说文本，保持原意但优化语句流畅度、文采和表达：\n\n$selectedText\n\n请直接输出润色后的文本，不需要额外解释。';
      final llm = LLMUseCase();
      final result = await llm.generateText(prompt, llmName);

      // 显示润色对比对话框
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('AI润色结果'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('原文:', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                    child: Text(selectedText, style: const TextStyle(fontSize: 14, height: 1.6)),
                  ),
                  const SizedBox(height: 16),
                  Text('润色后:', style: TextStyle(fontSize: 12, color: Colors.teal, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.teal[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.teal[100]!)),
                    child: Text(result, style: const TextStyle(fontSize: 14, height: 1.6)),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, 'decline'), child: const Text('放弃')),
            FilledButton(onPressed: () => Navigator.pop(ctx, 'accept'), child: const Text('接受润色')),
          ],
        ),
      );

      if (choice == 'accept') {
        final newText = _textCtrl.text.replaceRange(selection.start, selection.end, result);
        _textCtrl.text = newText;
        _textCtrl.selection = TextSelection.collapsed(offset: selection.start + result.length);
        setState(() => _polishing = false);
        _saveCurrent();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('润色完成 ✅'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('润色失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
    setState(() => _polishing = false);
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
      // 常见的地得混淆（仅在高置信度语境下替换，保留作为提示用）
      // '的'→'地'/'得' 的区分过于依赖上下文，不在此自动替换
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

    return LayoutBuilder(builder: (ctx, constraints) {
      final isWide = constraints.maxWidth > 600;
      if (isWide) {
        return Stack(children: [
          Row(children: [
      // 左侧：章节列表 (200px)
      SizedBox(
        width: 200,
        child: _loading ? const Center(child: CircularProgressIndicator()) : Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: FilledButton.icon(
                onPressed: _addChapter, icon: const Icon(Icons.add, size: 16),
                label: const Text('新章节'), style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 36)),
              ),
            ),
            // 章节跳转输入框
            if (_chapterNums.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: '跳转到第...章',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                        suffixIcon: InkWell(
                          onTap: () {}, // 占位，由 onSubmitted 处理
                          child: const Icon(Icons.arrow_forward, size: 16),
                        ),
                      ),
                      style: const TextStyle(fontSize: 12),
                      keyboardType: TextInputType.number,
                      onSubmitted: (v) {
                        final n = int.tryParse(v);
                        if (n != null && _chapterNums.contains(n)) _selectChapter(n);
                      },
                    ),
                  ),
                ]),
              ),
            if (_chapterNums.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    Icon(Icons.auto_stories, size: 36, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    Text('还没有章节', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                    const SizedBox(height: 4),
                    Text('点击上方按钮\n创建第一章', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                  ],
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
            // 底部章节统计
            if (_chapterNums.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text('共 ${_chapterNums.length} 章', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ),
          ],
        ),
      ),
      const VerticalDivider(width: 1),
      // 中间：编辑器 (flex比例随AI面板变化)
      Expanded(
        flex: _aiPanelExpanded ? 5 : 7,
        child: Column(children: [
          // 工具栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.grey[50], border: const Border(bottom: BorderSide(color: Color(0xFFE0E0E0)))),
            child: Row(children: [
              if (_currentChapter != null) Text('第$_currentChapter章', style: const TextStyle(fontWeight: FontWeight.bold)),
              if (_currentChapter == null) Text('未选择章节', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
              const Spacer(),
              _toolbarBtn(Icons.save, '保存', _currentChapter == null ? null : _saveCurrent),
              const SizedBox(width: 4),
              _toolbarBtn(Icons.spellcheck, '错字检查', _currentChapter == null || _correcting ? null : _checkTypos, isLoading: _correcting),
              // AI面板切换按钮
              IconButton(
                icon: Icon(_aiPanelExpanded ? Icons.auto_awesome : Icons.auto_awesome_outlined, size: 20, color: _aiPanelExpanded ? Colors.teal : Colors.grey),
                onPressed: () => setState(() => _aiPanelExpanded = !_aiPanelExpanded),
                tooltip: _aiPanelExpanded ? '收起AI面板' : '展开AI面板',
              ),
            ]),
          ),
          Expanded(
            child: _currentChapter == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_note, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('请选择或创建章节', style: TextStyle(fontSize: 16, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      Text('点击左侧「新章节」按钮创建第一章\n或从左侧列表中点击已有章节', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                    ],
                  ),
                )
              : TextField(
                  controller: _textCtrl,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: TextStyle(fontSize: _editorFontSize, height: 1.8, fontFamily: 'serif'),
                  decoration: const InputDecoration(
                    hintText: '在此撰写章节正文...\n\n💡 写作流程：\n1. 点击🔮展开AI面板输入大纲\n2. 点击「大纲→正文」让AI生成初稿\n3. 选中文本 → 「AI润色」优化语句\n4. 点击🔍检查错别字\n5. 点击💾保存章节',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                  contextMenuBuilder: _buildContextMenu,
                ),
          ),
        ]),
      ),
      // 右侧AI面板（可折叠）
      if (_aiPanelExpanded) ...[
        const VerticalDivider(width: 1),
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
                  const Spacer(),
                  InkWell(
                    onTap: () => setState(() => _aiPanelExpanded = false),
                    borderRadius: BorderRadius.circular(4),
                    child: Icon(Icons.close, size: 18, color: Colors.grey[400]),
                  ),
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
      ],
    ]),
    // AI面板收起后的悬浮按钮
    if (!_aiPanelExpanded)
      Positioned(
        right: 16,
        bottom: 16,
        child: FloatingActionButton(
          mini: true,
          backgroundColor: Colors.teal,
          onPressed: () => setState(() => _aiPanelExpanded = true),
          tooltip: '展开AI写作助手',
          child: const Icon(Icons.auto_awesome, size: 20, color: Colors.white),
        ),
      ),
  ]);
      } else {
        // 手机端：含底部工具栏的布局
        return Column(children: [
          // 顶部工具栏
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(children: [
              Expanded(child: FilledButton.icon(
                onPressed: _addChapter, icon: const Icon(Icons.add, size: 16),
                label: const Text('新章节'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 36)),
              )),
              const SizedBox(width: 8),
              Expanded(child: DropdownButton<int?>(
                value: _currentChapter, isExpanded: true,
                hint: const Text('选章节', style: TextStyle(fontSize: 13)),
                items: _chapterNums.map((n) => DropdownMenuItem(value: n, child: Text('第$n章', style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) { if (v != null) _selectChapter(v); },
              )),
            ]),
          ),
          // 编辑器
          Expanded(
            child: _currentChapter == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_note, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('请选择或创建章节', style: TextStyle(fontSize: 15, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                      const SizedBox(height: 6),
                      Text('点击「新章节」创建第一章\n或从下拉菜单选择已有章节', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                    ],
                  ),
                )
              : TextField(controller: _textCtrl, maxLines: null, expands: true, textAlignVertical: TextAlignVertical.top, style: TextStyle(fontSize: _editorFontSize), decoration: const InputDecoration(hintText: '在此撰写...', border: InputBorder.none, contentPadding: EdgeInsets.all(12)), contextMenuBuilder: _buildContextMenu),
          ),
          // 底部工具栏：保存 / 错字检查 / AI面板
          if (_currentChapter != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: const Border(top: BorderSide(color: Color(0xFFE0E0E0))),
              ),
              child: Row(children: [
                IconButton(icon: const Icon(Icons.save), onPressed: _saveCurrent, tooltip: '保存', iconSize: 22),
                IconButton(
                  icon: _correcting ? const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.spellcheck),
                  onPressed: _correcting ? null : _checkTypos, tooltip: '错字检查', iconSize: 22),
                const Spacer(),
                // AI面板按钮（底部Sheet形式）
                FilledButton.tonalIcon(
                  onPressed: _generating ? null : () => _showMobileAIPanel(context),
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('AI助手', style: TextStyle(fontSize: 13)),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    backgroundColor: Colors.teal.withAlpha(30),
                  ),
                ),
              ]),
            ),
        ]);
      }
    });
  }

  /// 手机端AI面板（底部Sheet）
  void _showMobileAIPanel(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollCtrl) => Column(children: [
          // 拖拽指示条
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              const Icon(Icons.auto_awesome, size: 20, color: Colors.teal),
              const SizedBox(width: 8),
              const Text('AI章节生成', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            ]),
          ),
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                const Text('📋 本章大纲', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                const SizedBox(height: 8),
                TextField(
                  controller: _outlineCtrl,
                  maxLines: 5,
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
                    onPressed: _generating ? null : () { _generateFromOutline(); Navigator.pop(sheetCtx); },
                    icon: _generating ? const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)) : const Icon(Icons.auto_awesome, size: 16),
                    label: Text(_generating ? 'AI生成中...' : '大纲→正文'),
                    style: FilledButton.styleFrom(backgroundColor: Colors.teal),
                  ),
                ),
                if (_generatedText != null) ...[
                  const SizedBox(height: 16),
                  Text('✨ 生成结果', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: Colors.teal[700])),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.teal[100]!)),
                    child: SelectableText(_generatedText!, style: const TextStyle(fontSize: 13, height: 1.6)),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    FilledButton.icon(onPressed: () { _applyGenerated(); Navigator.pop(sheetCtx); }, icon: const Icon(Icons.check, size: 16), label: const Text('应用到正文')),
                    const SizedBox(width: 8),
                    OutlinedButton(onPressed: () => setState(() => _generatedText = null), child: const Text('丢弃', style: TextStyle(color: Colors.red))),
                  ]),
                ],
                const SizedBox(height: 16),
                Text('💡 写作提示', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.grey[700])),
                _tip('大纲越详细，AI生成质量越高'),
                _tip('建议每章3000-5000字为佳'),
                _tip('生成后再手动润色去AI味'),
                _tip('点击🔍错字检查可自动发现常见错误'),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _toolbarBtn(IconData icon, String label, VoidCallback? onPressed, {bool isLoading = false}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          isLoading
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(icon, size: 14, color: Colors.grey[700]),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[700], fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  Widget _tip(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text('• $text', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
  );

  /// 自定义文本选择菜单，替换系统默认菜单
  Widget _buildContextMenu(BuildContext context, EditableTextState editableTextState) {
    final List<Widget> items = [];
    // 保留标准操作（剪切/复制/粘贴/全选）
    for (final item in editableTextState.contextMenuButtonItems) {
      items.add(
        TextButton(
          onPressed: item.onPressed,
          child: Text(item.label ?? ''),
        ),
      );
    }
    // 添加 AI润色 按钮
    items.add(
      TextButton.icon(
        onPressed: _polishing ? null : () {
          ContextMenuController.removeAny();
          _polishSelectedText();
        },
        icon: _polishing
            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.auto_awesome, size: 16),
        label: Text(_polishing ? '润色中...' : 'AI润色'),
      ),
    );
    // 添加 生成场景图 按钮
    items.add(
      TextButton.icon(
        onPressed: () {
          ContextMenuController.removeAny();
          _generateSceneImage();
        },
        icon: const Icon(Icons.image, size: 16, color: Colors.purple),
        label: const Text('场景图', style: TextStyle(color: Colors.purple)),
      ),
    );
    return AdaptiveTextSelectionToolbar(
      anchors: editableTextState.contextMenuAnchors,
      children: items,
    );
  }

  /// 根据选中文本生成场景插图
  Future<void> _generateSceneImage() async {
    final selection = _textCtrl.selection;
    final selectedText = selection.isValid && !selection.isCollapsed
        ? selection.textInside(_textCtrl.text)
        : _textCtrl.text.length > 500
            ? _textCtrl.text.substring(0, 500)
            : _textCtrl.text;

    if (selectedText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选中一段文字或确保章节有内容'), backgroundColor: Colors.red));
      return;
    }

    showDialog(context: context, barrierDismissible: false,
      builder: (_) => const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('AI正在生成场景插图...\n这可能需要30-60秒', textAlign: TextAlign.center, style: TextStyle(color: Colors.white)),
      ])),
    );

    try {
      final svc = ImageGenerationService();
      final imgPath = await svc.generateSceneImage(
        sceneText: selectedText,
        novelName: _novel!,
        chapterNum: _currentChapter,
      );
      if (mounted) Navigator.pop(context);
      if (imgPath != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('场景图已生成: $imgPath'), backgroundColor: Colors.green, duration: const Duration(seconds: 5)));
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('图片生成失败: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 5)));
      }
    }
  }
}

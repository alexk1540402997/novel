import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../presentation/widgets/navigation_drawer.dart';
import '../../presentation/widgets/novel_selector_dropdown.dart';
import '../../app/localizations/app_localizations.dart';
import '../../data/datasources/local/novel_file_service.dart';
import '../../domain/services/novel_folder_service.dart';
import '../../domain/services/novel_creation_service.dart';
import '../../domain/services/worldbook_service.dart';
import '../../domain/services/export_service.dart';
import '../../domain/services/logger_service.dart';
import '../../domain/services/context_memory_service.dart';
import '../../domain/usecases/llm_usecase.dart';
import '../../utils/config_service.dart';
import 'outline_page.dart';
import 'novel_architecture_page.dart'; // for SelectedNovelProvider
import 'worldbook_page.dart';
import 'chapter_writer_page.dart';
import 'character_page.dart';
import 'foreshadowing_page.dart';
import 'memory_overview_page.dart';
import 'other_settings_page.dart';
import 'large_model_settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final GlobalKey<NovelSelectorDropdownState> _novelSelectorKey =
      GlobalKey<NovelSelectorDropdownState>();

  static const List<({IconData icon, String labelKey, Widget page})>
      _navItems = [
    (icon: Icons.format_list_numbered, labelKey: 'nav_outline', page: OutlinePage()),
    (icon: Icons.edit_note, labelKey: 'nav_chapter_writer', page: ChapterWriterPage()),
    (icon: Icons.public, labelKey: 'nav_worldbook', page: WorldbookPage()),
    (icon: Icons.people, labelKey: 'nav_characters', page: CharacterPage()),
    (icon: Icons.lightbulb, labelKey: 'nav_foreshadowing', page: ForeshadowingPage()),
    (icon: Icons.memory, labelKey: 'nav_memory', page: MemoryOverviewPage()),
    (icon: Icons.settings, labelKey: 'nav_other_settings', page: OtherSettingsPage()),
    (icon: Icons.settings_applications, labelKey: 'nav_large_model_settings', page: LargeModelSettingsPage()),
  ];

  void _onDestinationSelected(int index) {
    setState(() => _selectedIndex = index);
  }

  /// 导出当前小说
  Future<void> _exportNovel() async {
    final novelName = context.read<SelectedNovelProvider>().selectedNovel;
    if (novelName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择一部小说'), backgroundColor: Colors.red),
      );
      return;
    }
    // 弹出格式选择对话框
    final format = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导出小说'),
        content: const Text('请选择导出格式：'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'txt'),
            child: const Text('TXT 文本'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'md'),
            child: const Text('Markdown'),
          ),
        ],
      ),
    );
    if (format == null) return;

    // 显示导出进度
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('正在导出...', style: TextStyle(color: Colors.white)),
        ],
      )),
    );

    try {
      final exportSvc = ExportService();
      final filePath = await exportSvc.exportToFile(novelName, novelName, format);
      if (mounted) Navigator.pop(context); // 关闭进度
      if (filePath != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导出成功！文件：$filePath'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// 打开创作向导
  Future<void> _showAddNovelDialog() async {
    final result = await Navigator.pushNamed(context, '/create_novel_wizard');
    if (result != null && result is Map<String, dynamic>) {
      await _createNovel(result);
    }
  }

  /// 创建小说并初始化模板内容
  Future<void> _createNovel(Map<String, dynamic> result) async {
    final novelName = result['name'] as String;
    final selection = result['selection'];
    final localizations = AppLocalizations.of(context);

    try {
      final novelsPath = await NovelFolderService().getNovelsFolderPath();
      final novelPath = '$novelsPath/$novelName';
      final novelDir = Directory(novelPath);
      if (await novelDir.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(localizations.translateWithArgs('novel_already_exists', [novelName])),
            backgroundColor: Colors.red,
          ));
        }
        return;
      }

      await novelDir.create(recursive: true);

      // 从模板初始化世界书、角色库、大纲
      if (selection != null) {
        try {
          final audience = selection.audience;
          final sub = selection.subCategory;
          await NovelCreationService().initializeFromTemplate(
            novelName: novelName,
            genreId: sub.id,
            genrePath: '${audience.name} → ${selection.majorCategory.name} → ${sub.name}',
            audienceName: audience.name,
          );
        } catch (e) {
          LoggerService().logError('Template init failed: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(localizations.translateWithArgs('novel_created_successfully', [novelName])),
          backgroundColor: Colors.green,
        ));
      }
      _novelSelectorKey.currentState?.refreshNovelFolders();
    } catch (e) {
      LoggerService().logError('Failed to create novel: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(localizations.translateWithArgs('failed_to_create_novel', [novelName])),
          backgroundColor: Colors.red,
        ));
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width >= 840) {
          return _buildExpandedLayout();
        } else if (width >= 600) {
          return _buildMediumLayout();
        } else {
          return _buildCompactLayout();
        }
      },
    );
  }

  // ===== 紧凑布局（手机 <600dp）：底部导航 + 全屏内容 =====
  Widget _buildCompactLayout() {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: NovelSelectorDropdown(
          key: _novelSelectorKey,
          onSelected: (folder) {
            if (folder != null) {
              context.read<SelectedNovelProvider>().setSelectedNovel(folder);
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _exportNovel,
            tooltip: '导出小说',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddNovelDialog,
            tooltip: localizations.translate('add_novel'),
          ),
        ],
      ),
      body: _navItems[_selectedIndex].page,
      // 手机端使用底部导航栏（最多显示5个，其余在"更多"菜单中）
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex < 5 ? _selectedIndex : 5, // 5=更多
        onDestinationSelected: (index) {
          if (index < 5) {
            _onDestinationSelected(index);
          } else {
            // 打开更多菜单
            Scaffold.of(context).openEndDrawer();
          }
        },
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 64,
        destinations: [
          const NavigationDestination(icon: Icon(Icons.format_list_numbered), label: '大纲'),
          const NavigationDestination(icon: Icon(Icons.edit_note), label: '写作'),
          const NavigationDestination(icon: Icon(Icons.public), label: '世界'),
          const NavigationDestination(icon: Icon(Icons.people), label: '角色'),
          const NavigationDestination(icon: Icon(Icons.lightbulb), label: '伏笔'),
          const NavigationDestination(icon: Icon(Icons.more_horiz), label: '更多'),
        ],
      ),
      // 保留抽屉用于"更多"菜单
      endDrawer: Drawer(
        child: SafeArea(
          child: Column(children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('更多功能', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const Divider(),
            ...List.generate(_navItems.length - 5, (i) {
              final idx = i + 5;
              final item = _navItems[idx];
              return ListTile(
                leading: Icon(item.icon),
                title: Text(localizations.translate(item.labelKey)),
                selected: _selectedIndex == idx,
                onTap: () {
                  _onDestinationSelected(idx);
                  Navigator.pop(context);
                },
              );
            }),
          ]),
        ),
      ),
    );
  }

  // ===== 中等布局（小PAD 600-840dp）：NavigationRail + 内容 =====
  Widget _buildMediumLayout() {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(localizations.translate(_navItems[_selectedIndex].labelKey)),
            const SizedBox(width: 12),
            NovelSelectorDropdown(
              key: _novelSelectorKey,
              onSelected: (folder) {
                if (folder != null) {
                  context.read<SelectedNovelProvider>().setSelectedNovel(folder);
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.file_download),
              onPressed: _exportNovel,
              tooltip: '导出小说',
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showAddNovelDialog,
              tooltip: localizations.translate('add_novel'),
            ),
          ],
        ),
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onDestinationSelected,
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Icon(Icons.auto_stories, color: Theme.of(context).primaryColor),
            ),
            destinations: _navItems
                .map((item) => NavigationRailDestination(
                      icon: Icon(item.icon),
                      label: Text(localizations.translate(item.labelKey)),
                    ))
                .toList(),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: _navItems[_selectedIndex].page,
          ),
        ],
      ),
    );
  }

  // ===== 扩展布局（大PAD ≥840dp）：Rail + 内容 + AI助手面板 =====
  Widget _buildExpandedLayout() {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(localizations.translate(_navItems[_selectedIndex].labelKey)),
            const SizedBox(width: 12),
            NovelSelectorDropdown(
              key: _novelSelectorKey,
              onSelected: (folder) {
                if (folder != null) {
                  context.read<SelectedNovelProvider>().setSelectedNovel(folder);
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.file_download),
              onPressed: _exportNovel,
              tooltip: '导出小说',
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showAddNovelDialog,
              tooltip: localizations.translate('add_novel'),
            ),
          ],
        ),
      ),
      body: Row(
        children: [
          // 左侧导航栏
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onDestinationSelected,
            labelType: NavigationRailLabelType.all,
            extended: false,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Icon(Icons.auto_stories, size: 32, color: Theme.of(context).primaryColor),
            ),
            destinations: _navItems
                .map((item) => NavigationRailDestination(
                      icon: Icon(item.icon),
                      label: Text(localizations.translate(item.labelKey)),
                    ))
                .toList(),
          ),
          const VerticalDivider(width: 1),
          // 主内容区（占满剩余宽度）
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _navItems[_selectedIndex].page,
            ),
          ),
        ],
      ),
    );
  }

  // ===== AI助手侧面板 =====
  Widget _buildAIAssistantPanel(AppLocalizations localizations) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHigh),
            child: Row(children: [
              Icon(Icons.auto_awesome, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              Text('AI 写作助手', style: Theme.of(context).textTheme.titleMedium),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: Consumer<SelectedNovelProvider>(
              builder: (ctx, novelProvider, _) {
                // 当小说变化时刷新信息
                final novelName = novelProvider.selectedNovel;
                if (novelName != _cachedNovelName) {
                  WidgetsBinding.instance.addPostFrameCallback((_) => _refreshNovelInfo(novelName));
                }
                return ListView(padding: const EdgeInsets.all(12), children: [
                  _aiBtn(Icons.auto_stories, 'AI续写', '基于前文上下文自动续写下一段', Colors.blue,
                    () => _onDestinationSelected(_kIdxChapterWriter)),
                  const SizedBox(height: 8),
                  _aiBtn(Icons.edit_note, 'AI润色', '优化当前选中文本的语句和文风', Colors.teal, () {
                    _onDestinationSelected(_kIdxChapterWriter);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('已切换到章节写作页，请在编辑器中选中文本后使用润色功能'), duration: Duration(seconds: 2)));
                  }),
                  const SizedBox(height: 8),
                  _aiBtn(Icons.lightbulb, '灵感建议', '根据当前上下文生成剧情灵感', Colors.orange, _showInspirationDialog),
                  const SizedBox(height: 8),
                  _aiBtn(Icons.spellcheck, '错字检查', '扫描当前章节的错别字和语法', Colors.purple, () {
                    _onDestinationSelected(_kIdxChapterWriter);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('请点击顶部工具栏的「错字检查」按钮开始扫描'), duration: Duration(seconds: 2)));
                  }),
                  const SizedBox(height: 8),
                  _aiBtn(Icons.summarize, '段落摘要', '自动生成章节摘要并存入写作记忆', Colors.indigo, _autoGenerateSummary),
                  const Divider(height: 20),
                  Text('📋 当前小说', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 6),
                  _infoCard(_cachedChannel, _cachedType, '$_cachedChapterCount'),
                ]);
              },
            ),
          ),
        ],
      ),
    );
  }

  // 索引常量（与 _navItems 数组对齐）
  static const _kIdxOutline = 0;
  static const _kIdxChapterWriter = 1;
  static const _kIdxWorldbook = 2;
  static const _kIdxCharacters = 3;
  static const _kIdxForeshadowing = 4;
  static const _kIdxMemory = 5;
  static const _kIdxOtherSettings = 6;
  static const _kIdxLargeModelSettings = 7;

  /// 当前页面是否为设置类页面（不需要AI面板）
  bool get _isSettingsPage => _selectedIndex >= _kIdxOtherSettings;

  Widget _aiBtn(IconData icon, String title, String sub, Color color, VoidCallback onTap) {
    return Card(
      elevation: 0, color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey[200]!)),
      child: InkWell(borderRadius: BorderRadius.circular(10), onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(10), child: Row(children: [
          CircleAvatar(radius: 16, backgroundColor: color.withAlpha(30), child: Icon(icon, size: 18, color: color)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
            Text(sub, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ])),
        ])),
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 1),
    child: Row(children: [
      SizedBox(width: 48, child: Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500]))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500))),
    ]),
  );

  Widget _infoCard(String channel, String type, String chapters) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _infoRow('📡 频道', channel),
        _infoRow('📂 类型', type),
        _infoRow('📝 章节', '$chapters 章'),
        const SizedBox(height: 2),
        Text('💡 点击上方AI按钮使用写作辅助功能',
          style: TextStyle(fontSize: 9, color: Colors.grey[400], fontStyle: FontStyle.italic)),
      ]),
    );
  }

  // 当前小说信息缓存
  String? _cachedNovelName;
  int _cachedChapterCount = 0;
  String _cachedChannel = '-';
  String _cachedType = '-';

  Future<void> _refreshNovelInfo(String? novelName) async {
    if (novelName == null) {
      setState(() {
        _cachedNovelName = null;
        _cachedChapterCount = 0;
        _cachedChannel = '-';
        _cachedType = '-';
      });
      return;
    }
    if (novelName == _cachedNovelName) return;
    _cachedNovelName = novelName;

    // 读取章节数量
    try {
      final chaps = await NovelFileService().getChapterNumbers(novelName);
      _cachedChapterCount = chaps.length;
    } catch (_) {
      _cachedChapterCount = 0;
    }

    // 尝试读取世界观库获取频道/类型
    try {
      final wbSvc = WorldbookService();
      final items = await wbSvc.loadAll(novelName);
      if (items.isNotEmpty) {
        final firstNote = items.first.notes;
        // 格式："来自模板：男频 · 男频 → 玄幻 → 东方玄幻"
        if (firstNote.startsWith('来自模板：')) {
          final parts = firstNote.substring(5).split('·');
          if (parts.length >= 2) {
            _cachedChannel = parts[0].trim();
            _cachedType = parts[1].trim().split('→').last.trim();
          } else if (parts.isNotEmpty) {
            _cachedChannel = parts[0].trim();
          }
        }
      }
    } catch (_) {
      _cachedChannel = '-';
      _cachedType = '-';
    }
    if (mounted) setState(() {});
  }

  /// 灵感建议：根据当前小说上下文生成剧情灵感
  Future<void> _showInspirationDialog() async {
    final novelName = context.read<SelectedNovelProvider>().selectedNovel;
    if (novelName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择一部小说'), backgroundColor: Colors.red));
      return;
    }
    // 显示加载
    showDialog(context: context, barrierDismissible: false,
      builder: (_) => const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('AI正在生成灵感建议...', style: TextStyle(color: Colors.white)),
      ])),
    );
    try {
      // 收集上下文
      final ctxBuf = StringBuffer();
      ctxBuf.writeln('频道：$_cachedChannel');
      ctxBuf.writeln('类型：$_cachedType');
      ctxBuf.writeln('章数：$_cachedChapterCount');
      // 尝试读取大纲概要
      try {
        final outlinePath = await NovelFolderService().getNovelsFolderPath();
        final outlineFile = File('$outlinePath/$novelName/outline.json');
        if (await outlineFile.exists()) {
          final json = jsonDecode(await outlineFile.readAsString());
          final title = json['title'] ?? '';
          final children = json['children'] as List<dynamic>? ?? [];
          ctxBuf.writeln('大纲概要：');
          for (final child in children) {
            ctxBuf.writeln('- ${child['title']}');
          }
        }
      } catch (_) {}

      final config = ConfigService().getAll();
      final llmName = config?['choose_configs']?['final_chapter_llm'] ?? 'Claude Sonnet 4.6';
      final prompt = '''你是一位资深网文编辑。以下是一部小说的基本信息，请基于此提供5个剧情灵感建议：

${ctxBuf.toString()}

请为每个灵感建议提供：
1. 灵感标题（简洁有力）
2. 一句话描述
3. 适合的章节位置（开头/中期/高潮/结尾）

请直接输出，每条灵感用"---"分隔。''';
      final llm = LLMUseCase();
      final result = await llm.generateText(prompt, llmName);
      if (mounted) Navigator.pop(context); // 关闭加载
      if (mounted) {
        // 解析结果
        final ideas = result.split('---').where((s) => s.trim().isNotEmpty).toList();
        showDialog(context: context, builder: (ctx) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.lightbulb, color: Colors.orange),
            SizedBox(width: 8),
            Text('灵感建议'),
          ]),
          content: SizedBox(width: double.maxFinite, child: ListView.builder(
            shrinkWrap: true, itemCount: ideas.length,
            itemBuilder: (_, i) => Card(
              color: Colors.orange[50],
              child: Padding(padding: const EdgeInsets.all(10),
                child: Text(ideas[i].trim(), style: const TextStyle(fontSize: 13, height: 1.5)),
              ),
            ),
          )),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭'))],
        ));
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('灵感生成失败: $e'), backgroundColor: Colors.red));
      }
    }
  }

  /// 自动生成章节摘要并存入写作记忆
  Future<void> _autoGenerateSummary() async {
    final novelName = context.read<SelectedNovelProvider>().selectedNovel;
    if (novelName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择一部小说'), backgroundColor: Colors.red));
      return;
    }
    showDialog(context: context, barrierDismissible: false,
      builder: (_) => const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('正在生成摘要...', style: TextStyle(color: Colors.white)),
      ])),
    );
    try {
      final fileSvc = NovelFileService();
      final chapters = await fileSvc.getChapterNumbers(novelName);
      if (chapters.isEmpty) {
        if (mounted) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('还没有章节内容'), backgroundColor: Colors.red));
        return;
      }
      // 读取最后一章
      final lastChapter = chapters.last;
      final content = await fileSvc.readChapter(novelName, lastChapter);
      if (content == null || content.trim().isEmpty) {
        if (mounted) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('章节内容为空'), backgroundColor: Colors.red));
        return;
      }
      final config = ConfigService().getAll();
      final llmName = config?['choose_configs']?['final_chapter_llm'] ?? 'Claude Sonnet 4.6';
      final prompt = '''请为以下小说章节生成写作记忆摘要：

$content

请以JSON返回（只要JSON）：
{"summary":"100字摘要","characters":["角色1"],"keyEvents":["事件1"],"wordCount":数字}''';
      final llm = LLMUseCase();
      final result = await llm.generateText(prompt, llmName);

      if (mounted) Navigator.pop(context);

      // 保存到写作记忆
      final memorySvc = ContextMemoryService();
      await memorySvc.load(novelName);
      try {
        final json = jsonDecode(result);
        final memory = ChapterMemory(
          chapterNumber: lastChapter,
          summary: json['summary'] ?? '',
          charactersAppeared: (json['characters'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
          keyEvents: (json['keyEvents'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
          wordCount: json['wordCount'] ?? content.length,
        );
        await memorySvc.updateChapter(memory);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('第${lastChapter}章摘要已生成并存入写作记忆 ✅'), backgroundColor: Colors.green, duration: const Duration(seconds: 3)));
        }
      } catch (_) {
        // 如果JSON解析失败，保存原始摘要
        final memory = ChapterMemory(
          chapterNumber: lastChapter,
          summary: result.length > 200 ? '${result.substring(0, 200)}...' : result,
          wordCount: content.length,
        );
        await memorySvc.updateChapter(memory);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('摘要已存入写作记忆 ✅'), backgroundColor: Colors.green));
        }
      }
      // 跳转到写作记忆页
      _onDestinationSelected(_kIdxMemory);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('摘要生成失败: $e'), backgroundColor: Colors.red));
      }
    }
  }
}

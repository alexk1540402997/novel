import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../presentation/widgets/navigation_drawer.dart';
import '../../presentation/widgets/novel_selector_dropdown.dart';
import '../../app/localizations/app_localizations.dart';
import '../../domain/services/novel_folder_service.dart';
import '../../domain/services/novel_creation_service.dart';
import '../../domain/services/logger_service.dart';
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
    (icon: Icons.public, labelKey: 'nav_worldbook', page: WorldbookPage()),
    (icon: Icons.edit_note, labelKey: 'nav_chapter_writer', page: ChapterWriterPage()),
    (icon: Icons.people, labelKey: 'nav_characters', page: CharacterPage()),
    (icon: Icons.lightbulb, labelKey: 'nav_foreshadowing', page: ForeshadowingPage()),
    (icon: Icons.memory, labelKey: 'nav_memory', page: MemoryOverviewPage()),
    (icon: Icons.settings, labelKey: 'nav_other_settings', page: OtherSettingsPage()),
    (icon: Icons.settings_applications, labelKey: 'nav_large_model_settings', page: LargeModelSettingsPage()),
  ];

  void _onDestinationSelected(int index) {
    setState(() => _selectedIndex = index);
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

  // ===== 紧凑布局（手机 <600dp）：抽屉 + 全屏内容 =====
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
            icon: const Icon(Icons.add),
            onPressed: _showAddNovelDialog,
            tooltip: localizations.translate('add_novel'),
          ),
        ],
      ),
      drawer: AppNavigationDrawer(
        onDestinationSelected: _onDestinationSelected,
        selectedIndex: _selectedIndex,
      ),
      body: _navItems[_selectedIndex].page,
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
            child: SingleChildScrollView(
              child: _navItems[_selectedIndex].page,
            ),
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
          // 主内容区
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _navItems[_selectedIndex].page,
            ),
          ),
          const VerticalDivider(width: 1),
          // 右侧AI助手面板
          Expanded(
            flex: 2,
            child: _buildAIAssistantPanel(localizations),
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
            child: ListView(padding: const EdgeInsets.all(12), children: [
              _aiBtn(Icons.auto_stories, 'AI续写', '基于前文上下文自动续写下一段', Colors.blue, () => _onDestinationSelected(1)),
              const SizedBox(height: 8),
              _aiBtn(Icons.edit_note, 'AI润色', '优化当前选中文本的语句和文风', Colors.teal, () {
                _onDestinationSelected(1);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请在章节写作页选中文本后使用润色功能'), duration: Duration(seconds: 2)));
              }),
              const SizedBox(height: 8),
              _aiBtn(Icons.lightbulb, '灵感建议', '根据当前大纲生成剧情灵感', Colors.orange, () {
                _onDestinationSelected(2); // 世界观库
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('灵感建议将在后续版本中接入AI'), duration: Duration(seconds: 2)));
              }),
              const SizedBox(height: 8),
              _aiBtn(Icons.spellcheck, '错字检查', '扫描当前章节的错别字和语法', Colors.purple, () {
                _onDestinationSelected(1);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已切换到章节写作页，点击🔍开始检查'), duration: Duration(seconds: 2)));
              }),
              const SizedBox(height: 8),
              _aiBtn(Icons.summarize, '段落摘要', '生成当前章节摘要存入写作记忆', Colors.indigo, () => _onDestinationSelected(5)),
              const Divider(height: 20),
              Text('📋 当前小说', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              _infoRow('频道', '-'),
              _infoRow('类型', '-'),
              _infoRow('总章节', '0'),
            ]),
          ),
        ],
      ),
    );
  }

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
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      SizedBox(width: 55, child: Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600]))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 11))),
    ]),
  );

}

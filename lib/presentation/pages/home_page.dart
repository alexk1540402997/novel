import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../presentation/widgets/navigation_drawer.dart';
import '../../presentation/widgets/novel_selector_dropdown.dart';
import '../../app/localizations/app_localizations.dart';
import '../../domain/services/novel_folder_service.dart';
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
      final novelName = result['name'] as String;
      await _createNovelFolder(novelName);
    }
  }

  /// 创建小说文件夹
  Future<void> _createNovelFolder(String novelName) async {
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
      } else {
        await novelDir.create(recursive: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(localizations.translateWithArgs('novel_created_successfully', [novelName])),
            backgroundColor: Colors.green,
          ));
        }
        _novelSelectorKey.currentState?.refreshNovelFolders();
      }
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
          // 面板标题
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text('AI 写作助手', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    // 后续：收起/展开面板
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 功能快捷入口
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildAICard(
                  icon: Icons.auto_stories,
                  title: 'AI续写',
                  subtitle: '基于上下文自动续写下一段',
                  color: Colors.blue,
                ),
                const SizedBox(height: 12),
                _buildAICard(
                  icon: Icons.edit_note,
                  title: 'AI润色',
                  subtitle: '优化语句、调整文风、去AI味',
                  color: Colors.teal,
                ),
                const SizedBox(height: 12),
                _buildAICard(
                  icon: Icons.lightbulb,
                  title: '灵感建议',
                  subtitle: '生成情节走向、角色对话灵感',
                  color: Colors.orange,
                ),
                const SizedBox(height: 12),
                _buildAICard(
                  icon: Icons.checklist,
                  title: '错字检查',
                  subtitle: '扫描章节错别字和语法问题',
                  color: Colors.purple,
                ),
                const SizedBox(height: 12),
                _buildAICard(
                  icon: Icons.summarize,
                  title: '段落摘要',
                  subtitle: '生成本章摘要方便上下文记忆',
                  color: Colors.indigo,
                ),
                const Divider(height: 24),
                // 当前项目信息
                Text('📋 小说信息', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                _buildNovelInfoRow('频道', '-'),
                _buildNovelInfoRow('类型', '-'),
                _buildNovelInfoRow('总字数', '-'),
                _buildNovelInfoRow('章节数', '-'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAICard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // 后续连接真实功能
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title — 功能开发中'), duration: const Duration(seconds: 1)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withAlpha(30),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                    Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNovelInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 60, child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}

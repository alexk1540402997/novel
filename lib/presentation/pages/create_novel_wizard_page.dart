import 'package:flutter/material.dart';
import '../../data/models/genre_category.dart';
import '../../data/repositories/genre_repository.dart';
import '../../data/repositories/template_repository.dart';

/// 新建小说多步骤创作向导
/// 步骤: 0级(男频/女频) → 1级(大类) → 2级(子类) → 3级(风格标签) → 模板预览+问题 → 命名
class CreateNovelWizardPage extends StatefulWidget {
  const CreateNovelWizardPage({super.key});

  @override
  State<CreateNovelWizardPage> createState() => _CreateNovelWizardPageState();
}

class _CreateNovelWizardPageState extends State<CreateNovelWizardPage> {
  final GenreRepository _genreRepo = GenreRepository();
  final PageController _pageController = PageController();
  final TextEditingController _nameController = TextEditingController();
  final Map<String, String> _answers = {};

  int _currentStep = 0;
  static const int _totalSteps = 6;

  // 用户选择
  GenreCategory? _selectedAudience;
  GenreCategory? _selectedMajor;
  GenreCategory? _selectedSub;
  final List<GenreCategory> _selectedTags = [];

  @override
  void initState() {
    super.initState();
    if (!_genreRepo.isInitialized) {
      _genreRepo.init();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  UserGenreSelection? _buildSelection() {
    if (_selectedAudience == null ||
        _selectedMajor == null ||
        _selectedSub == null) {
      return null;
    }
    return UserGenreSelection(
      audience: _selectedAudience!,
      majorCategory: _selectedMajor!,
      subCategory: _selectedSub!,
      styleTags: List.from(_selectedTags),
      questionAnswers: Map.from(_answers),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('创作向导 - 步骤 ${_currentStep + 1}/$_totalSteps'),
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _prevStep,
              )
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
      ),
      body: Column(
        children: [
          // 进度条
          LinearProgressIndicator(
            value: (_currentStep + 1) / _totalSteps,
            backgroundColor: Colors.grey[200],
          ),
          // 步骤内容
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) => setState(() => _currentStep = index),
              children: [
                _buildAudienceStep(),
                _buildMajorCategoryStep(),
                _buildSubCategoryStep(),
                _buildStyleTagsStep(),
                _buildTemplateStep(),
                _buildNameStep(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===== 步骤1: 选择男频/女频 =====
  Widget _buildAudienceStep() {
    final audiences = _genreRepo.getAudiences();
    return _buildSelectionStep(
      title: '选择频道',
      subtitle: '请选择你的目标读者群体',
      items: audiences,
      selectedItem: _selectedAudience,
      onSelected: (item) {
        setState(() {
          _selectedAudience = item;
          _selectedMajor = null;
          _selectedSub = null;
          _selectedTags.clear();
        });
        _nextStep();
      },
      color: Colors.blue,
    );
  }

  // ===== 步骤2: 选择大类 =====
  Widget _buildMajorCategoryStep() {
    if (_selectedAudience == null) return const SizedBox();
    final categories =
        _genreRepo.getMajorCategories(_selectedAudience!.id);
    return _buildSelectionStep(
      title: '选择类型',
      subtitle: '${_selectedAudience!.name} → 请选择小说类型',
      items: categories,
      selectedItem: _selectedMajor,
      onSelected: (item) {
        setState(() {
          _selectedMajor = item;
          _selectedSub = null;
          _selectedTags.clear();
        });
        _nextStep();
      },
      color: Colors.teal,
    );
  }

  // ===== 步骤3: 选择子类 =====
  Widget _buildSubCategoryStep() {
    if (_selectedAudience == null || _selectedMajor == null) {
      return const SizedBox();
    }
    final subCategories = _genreRepo.getSubCategories(
      _selectedAudience!.id,
      _selectedMajor!.id,
    );
    return _buildSelectionStep(
      title: '选择子类型',
      subtitle: '${_selectedAudience!.name} → ${_selectedMajor!.name} → 请选择子类型',
      items: subCategories,
      selectedItem: _selectedSub,
      onSelected: (item) {
        setState(() => _selectedSub = item);
        _nextStep();
      },
      color: Colors.orange,
    );
  }

  // ===== 步骤4: 选择风格标签（多选） =====
  Widget _buildStyleTagsStep() {
    if (_selectedAudience == null ||
        _selectedMajor == null ||
        _selectedSub == null) {
      return const SizedBox();
    }
    final tags = _genreRepo.getStyleTags(
      _selectedAudience!.id,
      _selectedMajor!.id,
      _selectedSub!.id,
    );

    if (tags.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _nextStep());
      return const SizedBox();
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '选择风格标签（可多选）',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            '${_selectedAudience!.name} → ${_selectedMajor!.name} → ${_selectedSub!.name}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: tags.map((tag) {
                final isSelected = _selectedTags.contains(tag);
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected ? Colors.orange : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: ListTile(
                    leading: Icon(
                      isSelected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: isSelected ? Colors.orange : Colors.grey,
                    ),
                    title: Text(tag.name),
                    subtitle: Text(tag.description),
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedTags.remove(tag);
                        } else {
                          _selectedTags.add(tag);
                        }
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          // 即使不选标签也可以继续
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: _nextStep,
                icon: const Text('跳过'),
                label: const Icon(Icons.arrow_forward),
              ),
              if (_selectedTags.isNotEmpty)
                FilledButton.icon(
                  onPressed: _nextStep,
                  icon: const Icon(Icons.arrow_forward),
                  label: Text('已选 ${_selectedTags.length} 个标签，继续'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ===== 步骤5: 模板预览 + 问题清单 + 代表作 =====
  Widget _buildTemplateStep() {
    final repo = TemplateRepository();
    var template = repo.getTemplateOrDefault(_selectedSub?.id ?? '');
    final ref = repo.getReference(_selectedSub?.id ?? '');

    // 标签融合
    if (_selectedTags.isNotEmpty) {
      final tagNames = _selectedTags.map((t) => t.name).toList();
      template = template.fuseTags(tagNames);
    }

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final isWide = constraints.maxWidth > 700;

        return Column(
          children: [
            Expanded(
              child: isWide
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // 左侧：模板内容（占 60%）
                    Expanded(flex: 3, child: _buildTemplateContent(template)),
                    const VerticalDivider(width: 1),
                    // 右侧：代表作推荐（占 40%）
                    Expanded(flex: 2, child: _buildReferencePanel(ref)),
                  ])
                : _buildTemplateContent(template),
            ),
            // 按钮固定底部
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Center(
                child: FilledButton.icon(
                  onPressed: _nextStep,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('继续'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTemplateContent(WritingTemplate template) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('模板与设定参考', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          '${_selectedAudience?.name} → ${_selectedMajor?.name} → ${_selectedSub?.name}${_selectedTags.isNotEmpty ? " · ${_selectedTags.map((t) => t.name).join("、")}" : ""}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
        ),
        if (_selectedTags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 6, runSpacing: 4,
              children: _selectedTags.map((t) => Chip(
                label: Text(t.name, style: const TextStyle(fontSize: 11)),
                backgroundColor: Colors.orange.withAlpha(20),
                side: BorderSide(color: Colors.orange.withAlpha(80)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              )).toList(),
            ),
          ),
        const Divider(height: 28),

        if (template.hasContent) ...[
          _templateSection('📖 全书大纲', template.bookOutline, Icons.book, Colors.teal),
          _templateSection('📚 分卷大纲', template.volumeOutlines, Icons.menu_book, Colors.indigo),
          _templateSection('🌍 世界观架构', template.worldbuildingArchitecture, Icons.public, Colors.blue),
          _templateSection('👥 角色模板', template.characterTemplates, Icons.people, Colors.orange),
        ] else
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(children: [
                Icon(Icons.auto_awesome, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('该类型暂无预设模板', style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 4),
                const Text('你可以直接创建空白项目，后续在\n大纲/世界观库/角色库中自行设定',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
              ]),
            ),
          ),
      ]),
    );
  }

  Widget _templateSection(String title, String content, IconData icon, Color color) {
    if (content.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withAlpha(60)),
        ),
        child: ExpansionTile(
          leading: Icon(icon, color: color, size: 22),
          title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: color)),
          initiallyExpanded: false,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SelectableText(
                content,
                style: const TextStyle(fontSize: 13, height: 1.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferencePanel(GenreReference? ref) {
    if (ref == null || ref.masterworks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.auto_stories, size: 40, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('暂无代表作数据', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          ]),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(ref.icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Text('代表作与名家', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 4),
        Text('同类作品参考，汲取创作灵感', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        const Divider(height: 24),
        ...ref.masterworks.map((m) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.grey[200]!),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.auto_stories, size: 16, color: Colors.teal[300]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(m.title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.person, size: 12, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text(m.author, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ]),
                const SizedBox(height: 2),
                Text(m.desc, style: TextStyle(fontSize: 11, color: Colors.grey[500], fontStyle: FontStyle.italic)),
              ]),
            ),
          ),
        )),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber[50],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.amber[100]!),
          ),
          child: Row(children: [
            const Icon(Icons.lightbulb, size: 18, color: Colors.amber),
            const SizedBox(width: 8),
            Expanded(
              child: Text('阅读同类作品有助于理解该类型的叙事节奏和读者期待，但不要模仿——找到自己的独特声音才是关键。',
                style: TextStyle(fontSize: 11, color: Colors.amber[900]!)),
            ),
          ]),
        ),
      ]),
    );
  }

  // ===== 步骤6: 命名 + 完成 =====
  Widget _buildNameStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.auto_stories, size: 64, color: Colors.teal),
          const SizedBox(height: 24),
          Text(
            '最后一步：为你的小说命名',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '${_selectedAudience?.name} · ${_selectedMajor?.name} · ${_selectedSub?.name}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
            textAlign: TextAlign.center,
          ),
          if (_selectedTags.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              children: _selectedTags
                  .map((t) => Chip(
                        label: Text(t.name, style: const TextStyle(fontSize: 12)),
                        backgroundColor: Colors.orange[50],
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 32),
          TextField(
            controller: _nameController,
            autofocus: true,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20),
            decoration: InputDecoration(
              hintText: '请输入小说名称',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.edit),
            ),
          ),
          const SizedBox(height: 24),

          // 总结面板
          Card(
            color: Colors.grey[50],
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📋 创建摘要',
                      style: Theme.of(context).textTheme.titleSmall),
                  const Divider(),
                  _buildSummaryRow('频道', _selectedAudience?.name ?? '-'),
                  _buildSummaryRow('类型', _selectedMajor?.name ?? '-'),
                  _buildSummaryRow('子类型', _selectedSub?.name ?? '-'),
                  _buildSummaryRow('风格标签',
                      _selectedTags.map((t) => t.name).join('、')),
                  if (_answers.isNotEmpty)
                    _buildSummaryRow(
                        '已回答问题', '${_answers.length} 个'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _onFinish,
            icon: const Icon(Icons.check),
            label: const Text('完成创建'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  /// 完成创建
  void _onFinish() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入小说名称'), backgroundColor: Colors.red),
      );
      return;
    }
    final selection = _buildSelection();
    if (selection == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请完成所有选择步骤'), backgroundColor: Colors.red),
      );
      return;
    }
    // 返回结果
    Navigator.pop(context, {
      'name': name,
      'selection': selection,
    });
  }

  // ===== 通用选择步骤组件 =====
  Widget _buildSelectionStep({
    required String title,
    required String subtitle,
    required List<GenreCategory> items,
    required GenreCategory? selectedItem,
    required void Function(GenreCategory) onSelected,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(_iconForLevel(items.isNotEmpty ? items.first.level : 1), color: color, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600])),
              ]),
            ),
            // 数量标签
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('${items.length} 个选项', style: TextStyle(fontSize: 12, color: color)),
            ),
          ]),
          const SizedBox(height: 20),
          Expanded(
            child: LayoutBuilder(builder: (ctx, constraints) {
              final crossAxisCount = constraints.maxWidth > 500 ? 3 : 2;
              final aspectRatio = constraints.maxWidth > 500 ? 1.6 : 2.0;
              return GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: aspectRatio,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isSelected = selectedItem?.id == item.id;
                  final catIcon = _iconForCategory(item.name, item.level);
                  final hasTemplate = item.template != null;
                  final hasChildren = item.children.isNotEmpty;
                  return Card(
                    elevation: isSelected ? 4 : 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: isSelected ? color : Colors.grey[200]!,
                        width: isSelected ? 2.5 : 1,
                      ),
                    ),
                    color: isSelected ? color.withAlpha(12) : null,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => onSelected(item),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 头部：图标 + 名称
                            Row(children: [
                              Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(
                                  color: isSelected ? color.withAlpha(40) : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(catIcon, size: 22, color: isSelected ? color : Colors.grey[600]),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(
                                    item.name,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected ? color : null,
                                    ),
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                  ),
                                  if (isSelected)
                                    Text('已选中', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
                                ]),
                              ),
                              if (isSelected)
                                Icon(Icons.check_circle, size: 22, color: color),
                            ]),
                            const SizedBox(height: 10),
                            // 描述
                            Expanded(
                              child: Text(
                                item.description,
                                style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.4),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // 底部标签
                            Row(children: [
                              if (hasTemplate)
                                _infoTag('有模板', Colors.green),
                              if (hasChildren)
                                _infoTag('${item.children.length} 子类', Colors.blue),
                              if (!hasTemplate && !hasChildren)
                                const Spacer(),
                              Icon(Icons.arrow_forward_ios, size: 12, color: isSelected ? color : Colors.grey[400]),
                            ]),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _infoTag(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    margin: const EdgeInsets.only(right: 6),
    decoration: BoxDecoration(
      color: color.withAlpha(20),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
  );

  IconData _iconForLevel(int level) {
    switch (level) {
      case 0: return Icons.group;
      case 1: return Icons.category;
      case 2: return Icons.style;
      case 3: return Icons.label;
      default: return Icons.auto_stories;
    }
  }

  IconData _iconForCategory(String name, int level) {
    final n = name.toLowerCase();
    if (n.contains('玄幻') || n.contains('仙侠') || n.contains('武侠')) return Icons.auto_fix_high;
    if (n.contains('都市') || n.contains('现实') || n.contains('职场')) return Icons.apartment;
    if (n.contains('历史') || n.contains('古代')) return Icons.history_edu;
    if (n.contains('科幻') || n.contains('末世')) return Icons.science;
    if (n.contains('悬疑') || n.contains('恐怖') || n.contains('灵异')) return Icons.psychology;
    if (n.contains('游戏') || n.contains('电竞')) return Icons.sports_esports;
    if (n.contains('军事')) return Icons.shield;
    if (n.contains('体育')) return Icons.sports;
    if (n.contains('言情') || n.contains('纯爱') || n.contains('恋爱')) return Icons.favorite;
    if (n.contains('轻小说') || n.contains('二次元')) return Icons.auto_stories;
    if (n.contains('奇幻') || n.contains('魔法')) return Icons.auto_awesome;
    if (n.contains('穿越') || n.contains('重生')) return Icons.swap_horiz;
    if (n.contains('系统') || n.contains('签到')) return Icons.settings_suggest;
    if (n.contains('种田') || n.contains('经营')) return Icons.agriculture;
    if (n.contains('无限流') || n.contains('诸天')) return Icons.all_inclusive;
    if (n.contains('盗墓') || n.contains('探险')) return Icons.explore;
    if (n.contains('虐文') || n.contains('虐恋')) return Icons.sentiment_dissatisfied;
    if (n.contains('甜宠') || n.contains('甜文')) return Icons.favorite_border;
    if (n.contains('爽文') || n.contains('无敌')) return Icons.bolt;
    if (n.contains('推理') || n.contains('侦探')) return Icons.search;
    return level == 0 ? Icons.group : (level == 3 ? Icons.label_outline : Icons.menu_book);
  }
}

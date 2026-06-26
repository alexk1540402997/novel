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

  // ===== 步骤5: 模板预览 + 问题清单 =====
  Widget _buildTemplateStep() {
    final template = TemplateRepository().getTemplateOrDefault(_selectedSub?.id ?? '');

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('模板与设定参考',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              '${_selectedAudience?.name} → ${_selectedMajor?.name} → ${_selectedSub?.name}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
            const Divider(height: 32),

            if (template.hasContent) ...[
              // 全书大纲
              if (template.bookOutline.isNotEmpty) ...[
                Text('📋 全书大纲模板', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  child: ExpansionTile(title: const Text('展开查看全书大纲'), children: [
                    Padding(padding: const EdgeInsets.all(16), child: SelectableText(template.bookOutline, style: const TextStyle(fontSize: 13, height: 1.6))),
                  ]),
                ),
                const SizedBox(height: 24),
              ],

              // 分卷大纲
              if (template.volumeOutlines.isNotEmpty) ...[
                Text('📚 分卷大纲模板', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  child: ExpansionTile(title: const Text('展开查看分卷大纲'), children: [
                    Padding(padding: const EdgeInsets.all(16), child: SelectableText(template.volumeOutlines, style: const TextStyle(fontSize: 13, height: 1.6))),
                  ]),
                ),
                const SizedBox(height: 24),
              ],

              // 世界观架构
              if (template.worldbuildingArchitecture.isNotEmpty) ...[
                Text('🌍 核心世界观架构', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  child: ExpansionTile(title: const Text('展开查看世界观架构'), children: [
                    Padding(padding: const EdgeInsets.all(16), child: SelectableText(template.worldbuildingArchitecture, style: const TextStyle(fontSize: 13, height: 1.6))),
                  ]),
                ),
                const SizedBox(height: 24),
              ],

              // 角色模板
              if (template.characterTemplates.isNotEmpty) ...[
                Text('👤 主要角色模板', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  child: ExpansionTile(title: const Text('展开查看角色模板'), children: [
                    Padding(padding: const EdgeInsets.all(16), child: SelectableText(template.characterTemplates, style: const TextStyle(fontSize: 13, height: 1.6))),
                  ]),
                ),
                const SizedBox(height: 24),
              ],
            ] else
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(children: [
                    Icon(Icons.auto_awesome, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text('该类型暂无预设模板', style: TextStyle(color: Colors.grey[600])),
                    const SizedBox(height: 4),
                    const Text('你可以直接创建空白项目，后续在\n大纲/世界观库/角色库中自行设定', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ]),
                ),
              ),

            const SizedBox(height: 24),
            Center(
              child: FilledButton.icon(
                onPressed: _nextStep,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('继续'),
              ),
            ),
          ],
        ),
      ),
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
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(subtitle,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey[600])),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.2,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = selectedItem?.id == item.id;
                return Card(
                  elevation: isSelected ? 4 : 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected ? color : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onSelected(item),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight:
                                  isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? color : null,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Expanded(
                            child: Text(
                              item.description,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/world_setting.dart';
import '../../domain/services/worldbook_service.dart';
import '../pages/novel_architecture_page.dart'; // SelectedNovelProvider

class WorldbookPage extends StatefulWidget {
  const WorldbookPage({super.key});

  @override
  State<WorldbookPage> createState() => _WorldbookPageState();
}

class _WorldbookPageState extends State<WorldbookPage> {
  List<WorldSetting> _allItems = [];
  List<WorldSetting> _filteredItems = [];
  String? _selectedCategory; // null = 显示"分类"提示, 筛选全部
  String? _selectedStatus;   // null = 显示"是否揭示"提示, 筛选全部
  final Set<String> _pinnedIds = {}; // 置顶条目ID集合
  String _searchQuery = '';
  bool _isLoading = false;
  String? _novelFolder;

  final WorldbookService _service = WorldbookService();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkNovel());
  }

  void _checkNovel() {
    final novel = context.read<SelectedNovelProvider>().selectedNovel;
    if (novel != _novelFolder) {
      _novelFolder = novel;
      if (novel != null) _loadItems();
    }
  }

  Future<void> _loadItems() async {
    if (_novelFolder == null) return;
    setState(() => _isLoading = true);
    final items = await _service.loadAll(_novelFolder!);
    setState(() {
      _allItems = items;
      _isLoading = false;
      _applyFilters();
    });
  }

  void _applyFilters() {
    var items = _allItems;
    if (_selectedCategory != null && _selectedCategory != '全部') {
      items = items.where((e) => e.category == _selectedCategory).toList();
    }
    if (_selectedStatus != null && _selectedStatus != '全部') {
      items = items.where((e) => e.status == _selectedStatus).toList();
    }
    // 置顶排序
    items = [
      ...items.where((e) => _pinnedIds.contains(e.id)),
      ...items.where((e) => !_pinnedIds.contains(e.id)),
    ];
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      items = items
          .where((e) =>
              e.name.toLowerCase().contains(q) ||
              e.description.toLowerCase().contains(q))
          .toList();
    }
    setState(() => _filteredItems = items);
  }

  Future<void> _deleteItem(WorldSetting item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除世界观条目「${item.name}」吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true && _novelFolder != null) {
      await _service.deleteItem(_novelFolder!, item.id);
      _loadItems();
    }
  }

  Future<void> _showEditDialog({WorldSetting? existing}) async {
    if (_novelFolder == null) return;
    final isNew = existing == null;
    final item = existing ??
        WorldSetting(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: '',
          category: '其他',
        );

    String name = item.name;
    String category = item.category;
    String description = item.description;
    String status = item.status;
    String notes = item.notes;
    String charInput = item.relatedCharacters.join('、');
    String chapterInput = item.relatedChapters.map((e) => e.toString()).join('、');

    final result = await showDialog<WorldSetting>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(isNew ? '新增世界观条目' : '编辑世界观条目'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  decoration: const InputDecoration(labelText: '名称', border: OutlineInputBorder(), isDense: true),
                  controller: TextEditingController(text: name),
                  onChanged: (v) => name = v,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: '分类', border: OutlineInputBorder(), isDense: true),
                  items: worldSettingCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setDlg(() => category = v ?? '其他'),
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(labelText: '描述', border: OutlineInputBorder(), isDense: true),
                  controller: TextEditingController(text: description),
                  onChanged: (v) => description = v,
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(labelText: '揭示状态', border: OutlineInputBorder(), isDense: true),
                  items: revealStatuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setDlg(() => status = v ?? '未揭示'),
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(labelText: '关联角色（名称用、分隔）', border: OutlineInputBorder(), isDense: true),
                  controller: TextEditingController(text: charInput),
                  onChanged: (v) => charInput = v,
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(labelText: '关联章节（章号用、分隔）', border: OutlineInputBorder(), isDense: true),
                  controller: TextEditingController(text: chapterInput),
                  onChanged: (v) => chapterInput = v,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(labelText: '备注/灵感', border: OutlineInputBorder(), isDense: true),
                  controller: TextEditingController(text: notes),
                  onChanged: (v) => notes = v,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: () {
                if (name.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('请输入名称')));
                  return;
                }
                final updated = WorldSetting(
                  id: item.id,
                  name: name.trim(),
                  category: category,
                  description: description,
                  status: status,
                  relatedCharacters: charInput.split('、').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
                  relatedChapters: chapterInput.split('、').map((e) => int.tryParse(e.trim()) ?? 0).where((e) => e > 0).toList(),
                  notes: notes,
                  createdAt: item.createdAt,
                );
                Navigator.pop(ctx, updated);
              },
              child: Text(isNew ? '添加' : '保存'),
            ),
          ],
        ),
      ),
    );

    if (result != null && _novelFolder != null) {
      if (isNew) {
        await _service.addItem(_novelFolder!, result);
      } else {
        await _service.updateItem(_novelFolder!, result);
      }
      _loadItems();
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case '已揭示':
        return Colors.green;
      case '已暗示':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final novel = context.watch<SelectedNovelProvider>().selectedNovel;
    if (novel != _novelFolder) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkNovel());
    }
    if (_novelFolder == null) {
      return const Center(child: Text('请先选择一部小说'));
    }

    return Column(
      children: [
        // 工具栏
        _buildToolbar(),
        // 统计栏
        _buildStatsBar(),
        // 列表
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.public_off, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(_allItems.isEmpty ? '世界观库为空，点击右上角+添加' : '没有匹配的条目',
                              style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredItems.length,
                      itemBuilder: (ctx, i) => _buildItemCard(_filteredItems[i]),
                    ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          // 搜索
          Expanded(
            flex: 3,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索世界观条目...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (v) {
                _searchQuery = v;
                _applyFilters();
              },
            ),
          ),
          const SizedBox(width: 12),
          // 分类筛选
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              value: _selectedCategory,
              hint: const Text('分类', style: TextStyle(fontSize: 13, color: Colors.grey)),
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: ['全部', ...worldSettingCategories]
                  .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _selectedCategory = v;
                  _applyFilters();
                });
              },
            ),
          ),
          const SizedBox(width: 12),
          // 状态筛选
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              value: _selectedStatus,
              hint: const Text('是否揭示', style: TextStyle(fontSize: 13, color: Colors.grey)),
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: ['全部', ...revealStatuses]
                  .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _selectedStatus = v;
                  _applyFilters();
                });
              },
            ),
          ),
          const SizedBox(width: 12),
          // 添加按钮
          FilledButton.icon(
            onPressed: () => _showEditDialog(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('添加'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    final total = _allItems.length;
    final revealed = _allItems.where((e) => e.status == '已揭示').length;
    final hinted = _allItems.where((e) => e.status == '已暗示').length;
    final hidden = _allItems.where((e) => e.status == '未揭示').length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _statChip('总计', total, Colors.blue),
          const SizedBox(width: 8),
          _statChip('已揭示', revealed, Colors.green),
          const SizedBox(width: 8),
          _statChip('已暗示', hinted, Colors.orange),
          const SizedBox(width: 8),
          _statChip('未揭示', hidden, Colors.grey),
        ],
      ),
    );
  }

  Widget _statChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text('$label: $count', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildItemCard(WorldSetting item) {
    final isPinned = _pinnedIds.contains(item.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: (isPinned ? Colors.amber : _statusColor(item.status)).withAlpha(isPinned ? 200 : 60)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showEditDialog(existing: item),
        child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              children: [
                if (isPinned)
                  const Icon(Icons.push_pin, size: 16, color: Colors.amber),
                Icon(_categoryIcon(item.category), size: 20, color: Colors.teal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _statusColor(item.status).withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _statusColor(item.status).withAlpha(80)),
                  ),
                  child: Text(item.status, style: TextStyle(fontSize: 11, color: _statusColor(item.status))),
                ),
                PopupMenuButton<String>(
                  iconSize: 18,
                  onSelected: (action) {
                    if (action == 'edit') _showEditDialog(existing: item);
                    if (action == 'pin') {
                      setState(() {
                        if (_pinnedIds.contains(item.id)) {
                          _pinnedIds.remove(item.id);
                        } else {
                          _pinnedIds.add(item.id);
                        }
                        _applyFilters();
                      });
                    }
                    if (action == 'delete') _deleteItem(item);
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'edit', child: Text('编辑')),
                    PopupMenuItem(
                      value: 'pin',
                      child: Text(_pinnedIds.contains(item.id) ? '取消置顶' : '置顶'),
                    ),
                    const PopupMenuItem(value: 'delete', child: Text('删除', style: TextStyle(color: Colors.red))),
                  ],
                ),
              ],
            ),
            if (item.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(item.description, style: TextStyle(fontSize: 13, color: Colors.grey[700]), maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
            // 标签行
            if (item.relatedCharacters.isNotEmpty || item.relatedChapters.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(6)),
                      child: Text(item.category, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    ),
                    ...item.relatedCharacters.map((c) => Chip(
                          label: Text(c, style: const TextStyle(fontSize: 10)),
                          avatar: const Icon(Icons.person, size: 12),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        )),
                    ...item.relatedChapters.map((ch) => Chip(
                          label: Text('第${ch}章', style: const TextStyle(fontSize: 10)),
                          avatar: const Icon(Icons.article, size: 12),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        )),
                  ],
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case '地理环境': return Icons.map;
      case '历史事件': return Icons.history;
      case '势力格局': return Icons.account_balance;
      case '修炼/魔法体系': return Icons.auto_fix_high;
      case '种族与生灵': return Icons.pets;
      case '天道/世界规则': return Icons.gavel;
      case '经济与资源': return Icons.monetization_on;
      case '文化风俗': return Icons.festival;
      case '科技水平': return Icons.science;
      default: return Icons.public;
    }
  }
}

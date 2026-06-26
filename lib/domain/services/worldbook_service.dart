import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../../data/models/world_setting.dart';
import 'novel_folder_service.dart';
import 'logger_service.dart';

/// 世界观库服务 — 管理结构化世界观设定条目
class WorldbookService {
  static final WorldbookService _instance = WorldbookService._();
  factory WorldbookService() => _instance;
  WorldbookService._();

  /// 获取世界观文件路径
  Future<String> _getWorldbookPath(String novelFolderName) async {
    final novelsPath = await NovelFolderService().getNovelsFolderPath();
    return path.join(novelsPath, novelFolderName, 'worldbook.json');
  }

  /// 加载世界观条目列表
  Future<List<WorldSetting>> loadAll(String novelFolderName) async {
    try {
      final filePath = await _getWorldbookPath(novelFolderName);
      final file = File(filePath);
      if (!await file.exists()) return [];
      final jsonStr = await file.readAsString();
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((e) => WorldSetting.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      LoggerService().logError('Failed to load worldbook: $e');
      return [];
    }
  }

  /// 保存全部条目
  Future<bool> saveAll(String novelFolderName, List<WorldSetting> items) async {
    try {
      final filePath = await _getWorldbookPath(novelFolderName);
      final file = File(filePath);
      await file.parent.create(recursive: true);
      final jsonStr =
          jsonEncode(items.map((e) => e.toJson()).toList());
      await file.writeAsString(jsonStr);
      return true;
    } catch (e) {
      LoggerService().logError('Failed to save worldbook: $e');
      return false;
    }
  }

  /// 添加条目
  Future<bool> addItem(String novelFolderName, WorldSetting item) async {
    final items = await loadAll(novelFolderName);
    items.add(item);
    return saveAll(novelFolderName, items);
  }

  /// 更新条目
  Future<bool> updateItem(
      String novelFolderName, WorldSetting updated) async {
    final items = await loadAll(novelFolderName);
    final index = items.indexWhere((e) => e.id == updated.id);
    if (index == -1) return false;
    items[index] = updated;
    return saveAll(novelFolderName, items);
  }

  /// 删除条目
  Future<bool> deleteItem(String novelFolderName, String id) async {
    final items = await loadAll(novelFolderName);
    items.removeWhere((e) => e.id == id);
    return saveAll(novelFolderName, items);
  }

  /// 按分类筛选
  List<WorldSetting> filterByCategory(
      List<WorldSetting> items, String category) {
    if (category == '全部') return items;
    return items.where((e) => e.category == category).toList();
  }

  /// 按状态筛选
  List<WorldSetting> filterByStatus(List<WorldSetting> items, String status) {
    if (status == '全部') return items;
    return items.where((e) => e.status == status).toList();
  }

  /// 获取该条目引用的章节列表（用于伏笔/关联）
  Map<int, List<WorldSetting>> groupByChapter(List<WorldSetting> items) {
    final map = <int, List<WorldSetting>>{};
    for (final item in items) {
      for (final chapter in item.relatedChapters) {
        map.putIfAbsent(chapter, () => []);
        map[chapter]!.add(item);
      }
    }
    return map;
  }
}

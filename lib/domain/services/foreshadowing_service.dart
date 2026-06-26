import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../../data/models/foreshadowing.dart';
import 'novel_folder_service.dart';
import 'logger_service.dart';

class ForeshadowingService {
  static final ForeshadowingService _instance = ForeshadowingService._();
  factory ForeshadowingService() => _instance;
  ForeshadowingService._();

  Future<String> _path(String novel) async {
    final base = await NovelFolderService().getNovelsFolderPath();
    return path.join(base, novel, 'foreshadowings.json');
  }

  Future<List<Foreshadowing>> loadAll(String novel) async {
    try {
      final fp = await _path(novel);
      final file = File(fp);
      if (!await file.exists()) return [];
      final list = jsonDecode(await file.readAsString()) as List<dynamic>;
      return list.map((e) => Foreshadowing.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) { LoggerService().logError('Load foreshadowings: $e'); return []; }
  }

  Future<bool> saveAll(String novel, List<Foreshadowing> items) async {
    try {
      final fp = await _path(novel);
      await File(fp).parent.create(recursive: true);
      await File(fp).writeAsString(jsonEncode(items.map((e) => e.toJson()).toList()));
      return true;
    } catch (e) { LoggerService().logError('Save foreshadowings: $e'); return false; }
  }

  Future<bool> add(String n, Foreshadowing f) async {
    final items = await loadAll(n); items.add(f); return saveAll(n, items);
  }
  Future<bool> update(String n, Foreshadowing f) async {
    final items = await loadAll(n);
    final idx = items.indexWhere((e) => e.id == f.id);
    if (idx == -1) return false; items[idx] = f; return saveAll(n, items);
  }
  Future<bool> delete(String n, String id) async {
    final items = await loadAll(n); items.removeWhere((e) => e.id == id);
    return saveAll(n, items);
  }

  /// 获取到达回收章节但未回收的伏笔（提醒用）
  List<Foreshadowing> getPendingReminders(List<Foreshadowing> items, int currentChapter) {
    return items.where((f) => f.remind && f.reapChapter > 0 && f.reapChapter <= currentChapter && f.status != '已回收').toList();
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../../data/models/character.dart';
import 'novel_folder_service.dart';
import 'logger_service.dart';

class CharacterService {
  static final CharacterService _instance = CharacterService._();
  factory CharacterService() => _instance;
  CharacterService._();

  Future<String> _getFilePath(String novelFolderName) async {
    final novelsPath = await NovelFolderService().getNovelsFolderPath();
    return path.join(novelsPath, novelFolderName, 'characters.json');
  }

  Future<List<NovelCharacter>> loadAll(String novelFolder) async {
    try {
      final fp = await _getFilePath(novelFolder);
      final file = File(fp);
      if (!await file.exists()) return [];
      final list = jsonDecode(await file.readAsString()) as List<dynamic>;
      return list
          .map((e) => NovelCharacter.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      LoggerService().logError('Failed to load characters: $e');
      return [];
    }
  }

  Future<bool> saveAll(String novelFolder, List<NovelCharacter> items) async {
    try {
      final fp = await _getFilePath(novelFolder);
      final file = File(fp);
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(items.map((e) => e.toJson()).toList()));
      return true;
    } catch (e) {
      LoggerService().logError('Failed to save characters: $e');
      return false;
    }
  }

  Future<bool> add(String novelFolder, NovelCharacter c) async {
    final items = await loadAll(novelFolder);
    items.add(c);
    return saveAll(novelFolder, items);
  }

  Future<bool> update(String novelFolder, NovelCharacter c) async {
    final items = await loadAll(novelFolder);
    final idx = items.indexWhere((e) => e.id == c.id);
    if (idx == -1) return false;
    items[idx] = c;
    return saveAll(novelFolder, items);
  }

  Future<bool> delete(String novelFolder, String id) async {
    final items = await loadAll(novelFolder);
    items.removeWhere((e) => e.id == id);
    return saveAll(novelFolder, items);
  }
}

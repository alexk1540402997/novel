import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../../data/repositories/template_repository.dart';
import '../../data/models/world_setting.dart';
import '../../data/models/character.dart';
import 'novel_folder_service.dart';
import 'logger_service.dart';

/// 小说创建服务 — 将模板内容注入到世界书、角色库和大纲
class NovelCreationService {
  static final NovelCreationService _instance = NovelCreationService._();
  factory NovelCreationService() => _instance;
  NovelCreationService._();

  /// 从模板初始化小说项目文件
  Future<void> initializeFromTemplate({
    required String novelName,
    required String genreId,
    required String genrePath, // "男频 → 玄幻 → 东方玄幻"
    required String audienceName, // "男频" or "女频"
  }) async {
    final novelsPath = await NovelFolderService().getNovelsFolderPath();
    final novelDir = Directory(path.join(novelsPath, novelName));
    await novelDir.create(recursive: true);

    final template = TemplateRepository().getTemplateOrDefault(genreId);
    if (!template.hasContent) return;

    // 1. 写入世界观库 (worldbook.json)
    await _initWorldbook(novelDir, template, audienceName, genrePath);

    // 2. 写入角色模板 (characters.json)
    await _initCharacters(novelDir, template);

    // 3. 写入大纲 (outline.json)
    await _initOutline(novelDir, template);

    LoggerService().logInfo('Initialized novel "$novelName" from template $genreId');
  }

  Future<void> _initWorldbook(Directory dir, WritingTemplate template, String audience, String genrePath) async {
    final entries = <WorldSetting>[];
    int idx = 0;

    void addEntry(String category, String name, String desc) {
      entries.add(WorldSetting(
        id: 'tpl_${idx++}',
        name: name,
        category: category,
        description: desc,
        status: '未揭示',
        notes: '来自模板：$audience · $genrePath',
      ));
    }

    // 解析世界书模板文本中的条目
    final lines = template.worldbuildingArchitecture.split('\n');
    String? currentCategory;
    String? currentTitle;
    final descBuf = StringBuffer();

    for (final line in lines) {
      if (line.startsWith('### ') || line.startsWith('## ')) {
        // 保存前一个条目
        if (currentTitle != null && currentCategory != null) {
          addEntry(currentCategory, currentTitle, descBuf.toString().trim());
          descBuf.clear();
        }
        currentCategory = line.replaceAll('#', '').trim();
        currentTitle = null;
      } else if (line.startsWith('- ') && currentCategory != null) {
        if (currentTitle != null) {
          addEntry(currentCategory, currentTitle, descBuf.toString().trim());
          descBuf.clear();
        }
        currentTitle = line.replaceAll('- ', '').trim();
      } else if (currentTitle != null) {
        if (line.trim().isNotEmpty) descBuf.writeln(line);
      }
    }
    // 最后一个条目
    if (currentTitle != null && currentCategory != null) {
      addEntry(currentCategory, currentTitle, descBuf.toString().trim());
    }

    // 如果没有解析出条目，至少添加模板路径信息
    if (entries.isEmpty) {
      addEntry('势力格局', '小说类型', genrePath);
      addEntry('天道/世界规则', '频道', audience);
    }

    final file = File(path.join(dir.path, 'worldbook.json'));
    await file.writeAsString(jsonEncode(entries.map((e) => e.toJson()).toList()));
  }

  Future<void> _initCharacters(Directory dir, WritingTemplate template) async {
    final entries = <NovelCharacter>[];
    int idx = 0;

    // 解析角色模板
    final text = template.characterTemplates;
    String? currentRole;
    final traits = <String, String>{};

    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('### ')) {
        if (currentRole != null && traits.isNotEmpty) {
          entries.add(_makeChar(idx++, currentRole, traits));
          traits.clear();
        }
        currentRole = trimmed.replaceAll('#', '').trim();
      } else if (trimmed.startsWith('- ') && currentRole != null) {
        final parts = trimmed.substring(2).split('：');
        if (parts.length >= 2) {
          traits[parts[0].trim()] = parts.sublist(1).join('：').trim();
        }
      }
    }
    if (currentRole != null && traits.isNotEmpty) {
      entries.add(_makeChar(idx++, currentRole, traits));
    }

    // 至少添加主角占位
    if (entries.isEmpty) {
      entries.add(NovelCharacter(
        id: 'tpl_0',
        name: '主角（待命名）',
        role: '主角',
        personality: ['待设定'],
        notes: '来自创作模板，请在角色库中完善',
      ));
    }

    final file = File(path.join(dir.path, 'characters.json'));
    await file.writeAsString(jsonEncode(entries.map((e) => e.toJson()).toList()));
  }

  NovelCharacter _makeChar(int idx, String role, Map<String, String> traits) {
    return NovelCharacter(
      id: 'tpl_$idx',
      name: traits['姓名'] ?? '$role（待命名）',
      role: role.contains('主角') ? '主角' : (role.contains('反派') ? '反派' : '配角'),
      gender: traits['性别'] ?? '男',
      personality: traits['性格']?.split('/') ?? [],
      faction: traits['定位'] ?? '',
      abilities: traits['能力']?.split('/') ?? [],
      notes: '来自创作模板，请在角色库中完善',
    );
  }

  Future<void> _initOutline(Directory dir, WritingTemplate template) async {
    // 构建初始大纲
    final root = _outlineFromTemplate(template);
    final file = File(path.join(dir.path, 'outline.json'));
    await file.writeAsString(jsonEncode(root));
  }

  Map<String, dynamic> _outlineFromTemplate(WritingTemplate template) {
    final children = <Map<String, dynamic>>[];

    if (template.bookOutline.isNotEmpty) {
      children.add({
        'title': '全书大纲',
        'content': template.bookOutline,
        'children': [],
      });
    }
    if (template.volumeOutlines.isNotEmpty) {
      final vols = <Map<String, dynamic>>[];
      for (final line in template.volumeOutlines.split('\n')) {
        if (line.trim().startsWith('### 卷')) {
          vols.add({'title': line.replaceAll('#', '').trim(), 'content': '', 'children': []});
        }
      }
      if (vols.isEmpty) {
        vols.add({'title': '分卷大纲', 'content': template.volumeOutlines, 'children': []});
      }
      children.add({'title': '分卷大纲', 'content': '', 'children': vols});
    }

    if (children.isEmpty) {
      children.add({'title': '全书大纲', 'content': '在此编写全书总纲...', 'children': []});
      children.add({'title': '分卷大纲', 'content': '', 'children': [{'title': '第一卷', 'content': '', 'children': []}]});
      children.add({'title': '章节大纲', 'content': '', 'children': [{'title': '第1章', 'content': '', 'children': []}]});
    }

    return {'title': '大纲', 'content': '', 'children': children};
  }
}

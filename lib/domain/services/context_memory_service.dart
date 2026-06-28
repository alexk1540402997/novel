import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'novel_folder_service.dart';
import 'logger_service.dart';

/// 章节记忆条目
class ChapterMemory {
  int chapterNumber;
  String summary; // AI生成或手动写的摘要
  List<String> charactersAppeared;
  List<String> worldSettingsUsed;
  List<String> keyEvents;
  int wordCount;
  String userNotes; // 用户手动补充的备注
  DateTime updatedAt;

  ChapterMemory({
    required this.chapterNumber,
    this.summary = '',
    this.charactersAppeared = const [],
    this.worldSettingsUsed = const [],
    this.keyEvents = const [],
    this.wordCount = 0,
    this.userNotes = '',
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  factory ChapterMemory.fromJson(Map<String, dynamic> json) {
    return ChapterMemory(
      chapterNumber: json['chapterNumber'] ?? 0,
      summary: json['summary'] ?? '',
      charactersAppeared: (json['charactersAppeared'] as List<dynamic>?)?.cast<String>() ?? [],
      worldSettingsUsed: (json['worldSettingsUsed'] as List<dynamic>?)?.cast<String>() ?? [],
      keyEvents: (json['keyEvents'] as List<dynamic>?)?.cast<String>() ?? [],
      wordCount: json['wordCount'] ?? 0,
      userNotes: json['userNotes'] ?? '',
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt']) ?? DateTime.now() : DateTime.now(),
    );
  }
  Map<String, dynamic> toJson() => {
    'chapterNumber': chapterNumber, 'summary': summary,
    'charactersAppeared': charactersAppeared, 'worldSettingsUsed': worldSettingsUsed,
    'keyEvents': keyEvents, 'wordCount': wordCount, 'userNotes': userNotes, 'updatedAt': updatedAt.toIso8601String(),
  };
}

/// 上下文记忆服务
/// 管理章节记忆索引，为AI续写提供上下文
class ContextMemoryService {
  static final ContextMemoryService _instance = ContextMemoryService._();
  factory ContextMemoryService() => _instance;
  ContextMemoryService._();

  String? _currentNovel;
  List<ChapterMemory> _memories = [];

  Future<String> _path() async {
    final base = await NovelFolderService().getNovelsFolderPath();
    return path.join(base, _currentNovel!, 'memory_index.json');
  }

  /// 加载记忆
  Future<void> load(String novelFolder) async {
    _currentNovel = novelFolder;
    try {
      final fp = await _path();
      final file = File(fp);
      if (!await file.exists()) { _memories = []; return; }
      final list = jsonDecode(await file.readAsString()) as List<dynamic>;
      _memories = list.map((e) => ChapterMemory.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) { LoggerService().logError('Load memory: $e'); _memories = []; }
  }

  /// 保存
  Future<void> _save() async {
    try {
      final fp = await _path();
      await File(fp).parent.create(recursive: true);
      await File(fp).writeAsString(jsonEncode(_memories.map((e) => e.toJson()).toList()));
    } catch (e) { LoggerService().logError('Save memory: $e'); }
  }

  /// 更新或添加章节记忆
  Future<void> updateChapter(ChapterMemory memory) async {
    final idx = _memories.indexWhere((m) => m.chapterNumber == memory.chapterNumber);
    if (idx >= 0) {
      _memories[idx] = memory;
    } else {
      _memories.add(memory);
      _memories.sort((a, b) => a.chapterNumber.compareTo(b.chapterNumber));
    }
    await _save();
  }

  /// 删除章节记忆
  Future<void> removeChapter(int chapterNum) async {
    _memories.removeWhere((m) => m.chapterNumber == chapterNum);
    await _save();
  }

  /// 获取章节记忆
  ChapterMemory? getChapter(int chapterNum) {
    return _memories.where((m) => m.chapterNumber == chapterNum).firstOrNull;
  }

  /// 获取全部章节记忆
  List<ChapterMemory> get allMemories => List.unmodifiable(_memories);

  /// 获取总字数
  int get totalWordCount => _memories.fold(0, (sum, m) => sum + m.wordCount);

  /// 获取所有出场过的角色
  Set<String> get allCharacters {
    final chars = <String>{};
    for (final m in _memories) { chars.addAll(m.charactersAppeared); }
    return chars;
  }

  /// 构建AI续写上下文（最近的N章摘要 + 角色状态）
  String buildContinuationContext(int currentChapter, {int lookback = 5}) {
    if (_memories.isEmpty) return '';

    final recent = _memories
        .where((m) => m.chapterNumber < currentChapter && m.chapterNumber >= currentChapter - lookback)
        .toList()
      ..sort((a, b) => a.chapterNumber.compareTo(b.chapterNumber));

    if (recent.isEmpty) return '';

    final buf = StringBuffer();
    buf.writeln('=== 前文回顾（最近${recent.length}章） ===');
    for (final m in recent) {
      buf.writeln('第${m.chapterNumber}章摘要：${m.summary.isNotEmpty ? m.summary : "(暂无摘要)"}');
      if (m.charactersAppeared.isNotEmpty) {
        buf.writeln('  出场角色：${m.charactersAppeared.join("、")}');
      }
      if (m.keyEvents.isNotEmpty) {
        buf.writeln('  关键事件：${m.keyEvents.join("；")}');
      }
    }
    buf.writeln('=== 请基于以上前文内容，自然衔接续写 ===');
    return buf.toString();
  }

  /// 构建全书摘要
  String buildFullBookSummary() {
    if (_memories.isEmpty) return '暂无章节记录';
    final buf = StringBuffer();
    buf.writeln('本书共${_memories.length}章，总字数约${totalWordCount}字');
    buf.writeln('');
    for (final m in _memories) {
      if (m.summary.isNotEmpty) {
        buf.writeln('第${m.chapterNumber}章：${m.summary}');
      }
    }
    return buf.toString();
  }

  /// 获取需要提醒的伏笔相关章节（用于上下文提示）
  List<int> getChaptersWithActiveForeshadowings(List<int> reapChapters, int currentChapter) {
    return reapChapters.where((ch) => ch > 0 && ch <= currentChapter).toList();
  }
}

import 'dart:convert';
import 'package:flutter/services.dart';

class WritingTemplate {
  final String bookOutline;
  final String volumeOutlines;
  final String worldbuildingArchitecture;
  final String characterTemplates;

  WritingTemplate({
    this.bookOutline = '',
    this.volumeOutlines = '',
    this.worldbuildingArchitecture = '',
    this.characterTemplates = '',
  });

  factory WritingTemplate.fromJson(Map<String, dynamic> json) => WritingTemplate(
    bookOutline: json['book_outline'] ?? '',
    volumeOutlines: json['volume_outlines'] ?? '',
    worldbuildingArchitecture: json['worldbuilding_architecture'] ?? '',
    characterTemplates: json['character_templates'] ?? '',
  );

  bool get hasContent => bookOutline.isNotEmpty || volumeOutlines.isNotEmpty;

  /// 融合标签内容到模板中（将标签特定描述融合到通用模板）
  WritingTemplate fuseTags(List<String> tagNames) {
    if (tagNames.isEmpty) return this;
    final tagFusion = tagNames.map((t) => '· $t').join('\n');
    return WritingTemplate(
      bookOutline: '$bookOutline\n\n🎯 融合风格标签：\n$tagFusion\n\n提示：以上标签风格将融入创作，确保不同风格要素自然融合而非简单堆砌。',
      volumeOutlines: volumeOutlines,
      worldbuildingArchitecture: worldbuildingArchitecture,
      characterTemplates: characterTemplates,
    );
  }
}

class GenreReference {
  final String icon;
  final List<({String title, String author, String desc})> masterworks;
  GenreReference({this.icon = '📖', this.masterworks = const []});
  factory GenreReference.fromJson(Map<String, dynamic> json) {
    final mw = <({String title, String author, String desc})>[];
    final rawList = json['masterworks'] as List?;
    if (rawList != null) {
      for (final m in rawList) {
        mw.add((
          title: (m['title'] ?? '') as String,
          author: (m['author'] ?? '') as String,
          desc: (m['desc'] ?? '') as String,
        ));
      }
    }
    return GenreReference(icon: json['icon'] ?? '📖', masterworks: mw);
  }
}

class TemplateRepository {
  static final TemplateRepository _instance = TemplateRepository._();
  factory TemplateRepository() => _instance;
  TemplateRepository._();

  Map<String, WritingTemplate> _templates = {};
  Map<String, GenreReference> _references = {};
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      final jsonStr = await rootBundle.loadString('assets/data/writing_templates.json');
      final data = jsonDecode(jsonStr);
      final tmpl = data['templates'] as Map<String, dynamic>;
      tmpl.forEach((key, value) {
        _templates[key] = WritingTemplate.fromJson(value);
      });
    } catch (_) { /* 使用空模板 */ }
    try {
      final refStr = await rootBundle.loadString('assets/data/genre_references.json');
      final refData = jsonDecode(refStr);
      final refs = refData['references'] as Map<String, dynamic>?;
      if (refs != null) {
        refs.forEach((key, value) {
          _references[key] = GenreReference.fromJson(value);
        });
      }
    } catch (_) { /* 无代表作数据 */ }
    _initialized = true;
  }

  WritingTemplate? getTemplate(String genreId) => _templates[genreId];

  /// 获取模板或返回默认模板
  WritingTemplate getTemplateOrDefault(String genreId) {
    return _templates[genreId] ?? WritingTemplate();
  }

  /// 获取某类目的代表作参考
  GenreReference? getReference(String genreId) => _references[genreId];
}

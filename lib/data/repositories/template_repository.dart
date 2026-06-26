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
}

class TemplateRepository {
  static final TemplateRepository _instance = TemplateRepository._();
  factory TemplateRepository() => _instance;
  TemplateRepository._();

  Map<String, WritingTemplate> _templates = {};
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
    _initialized = true;
  }

  WritingTemplate? getTemplate(String genreId) => _templates[genreId];

  /// 获取模板或返回默认模板
  WritingTemplate getTemplateOrDefault(String genreId) {
    return _templates[genreId] ?? WritingTemplate();
  }
}

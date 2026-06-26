import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/genre_category.dart';

/// 类型类目数据仓储
/// 从 assets/data/genres.json 加载完整的类型类目树
class GenreRepository {
  static final GenreRepository _instance = GenreRepository._();
  factory GenreRepository() => _instance;
  GenreRepository._();

  List<GenreCategory> _audiences = [];
  bool _initialized = false;

  bool get isInitialized => _initialized;
  List<GenreCategory> get audiences => _audiences;

  /// 初始化：加载genres.json
  Future<void> init() async {
    if (_initialized) return;
    try {
      final jsonStr =
          await rootBundle.loadString('assets/data/genres.json');
      final jsonData = jsonDecode(jsonStr) as Map<String, dynamic>;
      final audienceList = jsonData['audiences'] as List<dynamic>;
      _audiences = audienceList
          .map((e) => GenreCategory.fromJson(e as Map<String, dynamic>))
          .toList();
      _initialized = true;
    } catch (e) {
      // 如果加载失败，使用空列表
      _audiences = [];
      _initialized = true;
    }
  }

  /// 获取所有0级类目（男频/女频）
  List<GenreCategory> getAudiences() => _audiences;

  /// 获取指定0级类目下的所有1级类目
  List<GenreCategory> getMajorCategories(String audienceId) {
    final audience = _audiences.where((a) => a.id == audienceId).firstOrNull;
    return audience?.children ?? [];
  }

  /// 获取指定1级类目下的所有2级类目
  List<GenreCategory> getSubCategories(
      String audienceId, String majorCategoryId) {
    final majorCategories = getMajorCategories(audienceId);
    final major =
        majorCategories.where((m) => m.id == majorCategoryId).firstOrNull;
    return major?.children ?? [];
  }

  /// 获取指定2级类目下的所有3级风格标签
  List<GenreCategory> getStyleTags(
      String audienceId, String majorCategoryId, String subCategoryId) {
    final subCategories = getSubCategories(audienceId, majorCategoryId);
    final sub =
        subCategories.where((s) => s.id == subCategoryId).firstOrNull;
    return sub?.children ?? [];
  }
}

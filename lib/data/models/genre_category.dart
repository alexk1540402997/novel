/// 小说类型类目数据模型
/// 0级: 男频/女频 → 1级: 大类 → 2级: 子类 → 3级: 风格标签

class GenreCategory {
  final String id;
  final String name;
  final String description;
  final int level; // 0=男频/女频, 1=大类, 2=子类, 3=风格标签
  final List<GenreCategory> children;
  final GenreTemplate? template;

  GenreCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.level,
    this.children = const [],
    this.template,
  });

  factory GenreCategory.fromJson(Map<String, dynamic> json) {
    return GenreCategory(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      level: json['level'] ?? 1,
      children: (json['children'] as List<dynamic>?)
              ?.map((e) => GenreCategory.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      template: json['template'] != null
          ? GenreTemplate.fromJson(json['template'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'level': level,
      'children': children.map((e) => e.toJson()).toList(),
      'template': template?.toJson(),
    };
  }

  /// 获取所有叶子节点（风格标签层）
  List<GenreCategory> getLeafCategories() {
    if (children.isEmpty) {
      return [this];
    }
    return children.expand((c) => c.getLeafCategories()).toList();
  }
}

/// 类型模板 — 包含大纲模板、世界观模板、问题清单
class GenreTemplate {
  final List<OutlineTemplate> outlines;
  final List<WorldbuildingTemplate> worldbuilding;
  final List<ChecklistQuestion> questions;

  GenreTemplate({
    this.outlines = const [],
    this.worldbuilding = const [],
    this.questions = const [],
  });

  factory GenreTemplate.fromJson(Map<String, dynamic> json) {
    return GenreTemplate(
      outlines: (json['outlines'] as List<dynamic>?)
              ?.map((e) =>
                  OutlineTemplate.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      worldbuilding: (json['worldbuilding'] as List<dynamic>?)
              ?.map((e) =>
                  WorldbuildingTemplate.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      questions: (json['questions'] as List<dynamic>?)
              ?.map((e) =>
                  ChecklistQuestion.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'outlines': outlines.map((e) => e.toJson()).toList(),
      'worldbuilding': worldbuilding.map((e) => e.toJson()).toList(),
      'questions': questions.map((e) => e.toJson()).toList(),
    };
  }
}

/// 大纲模板
class OutlineTemplate {
  final String title;
  final String content; // Markdown格式

  OutlineTemplate({required this.title, required this.content});

  factory OutlineTemplate.fromJson(Map<String, dynamic> json) {
    return OutlineTemplate(
      title: json['title'] ?? '',
      content: json['content'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'title': title, 'content': content};
}

/// 世界观设定模板
class WorldbuildingTemplate {
  final String category; // 地理/历史/势力/规则...
  final String title;
  final String prompt; // 引导用户填写的提示

  WorldbuildingTemplate({
    required this.category,
    required this.title,
    required this.prompt,
  });

  factory WorldbuildingTemplate.fromJson(Map<String, dynamic> json) {
    return WorldbuildingTemplate(
      category: json['category'] ?? '',
      title: json['title'] ?? '',
      prompt: json['prompt'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'category': category,
        'title': title,
        'prompt': prompt,
      };
}

/// 创作前问题清单
class ChecklistQuestion {
  final String question;
  final String category; // 角色/世界观/情节/风格...
  final List<String> suggestions; // 可选建议答案

  ChecklistQuestion({
    required this.question,
    required this.category,
    this.suggestions = const [],
  });

  factory ChecklistQuestion.fromJson(Map<String, dynamic> json) {
    return ChecklistQuestion(
      question: json['question'] ?? '',
      category: json['category'] ?? '',
      suggestions:
          (json['suggestions'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
        'question': question,
        'category': category,
        'suggestions': suggestions,
      };
}

/// 用户创作选择结果
class UserGenreSelection {
  final GenreCategory audience; // 男频/女频
  final GenreCategory majorCategory; // 玄幻/都市...
  final GenreCategory subCategory; // 东方玄幻/修真流...
  final List<GenreCategory> styleTags; // 风格标签
  final Map<String, String> questionAnswers; // 问题ID → 答案

  UserGenreSelection({
    required this.audience,
    required this.majorCategory,
    required this.subCategory,
    this.styleTags = const [],
    this.questionAnswers = const {},
  });
}

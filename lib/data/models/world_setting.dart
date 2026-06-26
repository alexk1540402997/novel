/// 世界观设定条目
class WorldSetting {
  final String id;
  String name;
  String category;
  String description;
  List<String> relatedCharacters;
  List<int> relatedChapters;
  String status; // 已揭示 / 已暗示 / 未揭示
  String notes;
  final DateTime createdAt;
  DateTime updatedAt;

  WorldSetting({
    required this.id,
    this.name = '',
    this.category = '其他',
    this.description = '',
    this.relatedCharacters = const [],
    this.relatedChapters = const [],
    this.status = '未揭示',
    this.notes = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory WorldSetting.fromJson(Map<String, dynamic> json) {
    return WorldSetting(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? '其他',
      description: json['description'] ?? '',
      relatedCharacters: (json['relatedCharacters'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      relatedChapters: (json['relatedChapters'] as List<dynamic>?)
              ?.map((e) => int.tryParse(e.toString()) ?? 0)
              .where((e) => e > 0)
              .toList() ??
          [],
      status: json['status'] ?? '未揭示',
      notes: json['notes'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'description': description,
        'relatedCharacters': relatedCharacters,
        'relatedChapters': relatedChapters,
        'status': status,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  WorldSetting copyWith({
    String? name,
    String? category,
    String? description,
    List<String>? relatedCharacters,
    List<int>? relatedChapters,
    String? status,
    String? notes,
  }) {
    return WorldSetting(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      relatedCharacters: relatedCharacters ?? this.relatedCharacters,
      relatedChapters: relatedChapters ?? this.relatedChapters,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

/// 世界观预设分类
const worldSettingCategories = [
  '地理环境',
  '历史事件',
  '势力格局',
  '修炼/魔法体系',
  '种族与生灵',
  '天道/世界规则',
  '经济与资源',
  '文化风俗',
  '科技水平',
  '其他',
];

/// 揭示状态
const revealStatuses = ['已揭示', '已暗示', '未揭示'];

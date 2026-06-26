/// 伏笔条目
class Foreshadowing {
  final String id;
  String name;
  String description;
  int plantChapter; // 埋设章节
  String plantNode; // 埋设位置（大纲节点描述）
  int reapChapter; // 计划回收章节
  String reapNode; // 回收位置（大纲节点描述）
  List<String> relatedCharacters; // 关联角色名
  List<String> relatedSettings; // 关联世界观设定ID/名称
  String status; // 已埋 / 部分揭示 / 已回收
  List<String> linkedIds; // 关联伏笔ID列表
  bool remind; // 是否提醒
  String notes;
  final DateTime createdAt;
  DateTime updatedAt;

  Foreshadowing({
    required this.id,
    this.name = '',
    this.description = '',
    this.plantChapter = 0,
    this.plantNode = '',
    this.reapChapter = 0,
    this.reapNode = '',
    this.relatedCharacters = const [],
    this.relatedSettings = const [],
    this.status = '已埋',
    this.linkedIds = const [],
    this.remind = false,
    this.notes = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Foreshadowing.fromJson(Map<String, dynamic> json) {
    return Foreshadowing(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      plantChapter: json['plantChapter'] ?? 0,
      plantNode: json['plantNode'] ?? '',
      reapChapter: json['reapChapter'] ?? 0,
      reapNode: json['reapNode'] ?? '',
      relatedCharacters: (json['relatedCharacters'] as List<dynamic>?)?.cast<String>() ?? [],
      relatedSettings: (json['relatedSettings'] as List<dynamic>?)?.cast<String>() ?? [],
      status: json['status'] ?? '已埋',
      linkedIds: (json['linkedIds'] as List<dynamic>?)?.cast<String>() ?? [],
      remind: json['remind'] ?? false,
      notes: json['notes'] ?? '',
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) ?? DateTime.now() : DateTime.now(),
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt']) ?? DateTime.now() : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'description': description,
        'plantChapter': plantChapter, 'plantNode': plantNode,
        'reapChapter': reapChapter, 'reapNode': reapNode,
        'relatedCharacters': relatedCharacters, 'relatedSettings': relatedSettings,
        'status': status, 'linkedIds': linkedIds, 'remind': remind, 'notes': notes,
        'createdAt': createdAt.toIso8601String(), 'updatedAt': updatedAt.toIso8601String(),
      };
}

const foreshadowingStatuses = ['已埋', '部分揭示', '已回收'];

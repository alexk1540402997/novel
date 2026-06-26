/// 角色关系
class CharacterRelation {
  String targetName; // 对方角色名
  String type; // 关系类型：师徒/恋人/敌对/朋友/亲人/同门/同盟/上下级/其他
  String description; // 关系描述

  CharacterRelation({
    required this.targetName,
    this.type = '其他',
    this.description = '',
  });

  factory CharacterRelation.fromJson(Map<String, dynamic> json) {
    return CharacterRelation(
      targetName: json['targetName'] ?? '',
      type: json['type'] ?? '其他',
      description: json['description'] ?? '',
    );
  }
  Map<String, dynamic> toJson() =>
      {'targetName': targetName, 'type': type, 'description': description};
}

/// 关键事件（角色重要时间节点）
class CharacterEvent {
  int chapter;
  String event;

  CharacterEvent({required this.chapter, required this.event});

  factory CharacterEvent.fromJson(Map<String, dynamic> json) {
    return CharacterEvent(
      chapter: json['chapter'] ?? 0,
      event: json['event'] ?? '',
    );
  }
  Map<String, dynamic> toJson() => {'chapter': chapter, 'event': event};
}

/// 角色
class NovelCharacter {
  final String id;
  String name;
  String gender; // 男/女/其他
  String age; // 年龄或年龄描述
  String appearance; // 外貌描述
  List<String> personality; // 性格标签
  String role; // 主角/配角/反派/路人
  String faction; // 所属势力
  List<String> abilities; // 能力/技能
  List<CharacterRelation> relationships; // 关系列表
  int firstChapter; // 首次出场章节
  List<CharacterEvent> keyEvents; // 关键事件
  String currentStatus; // 当前状态
  String notes; // 备注
  final DateTime createdAt;
  DateTime updatedAt;

  NovelCharacter({
    required this.id,
    this.name = '',
    this.gender = '男',
    this.age = '',
    this.appearance = '',
    this.personality = const [],
    this.role = '配角',
    this.faction = '',
    this.abilities = const [],
    this.relationships = const [],
    this.firstChapter = 0,
    this.keyEvents = const [],
    this.currentStatus = '',
    this.notes = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory NovelCharacter.fromJson(Map<String, dynamic> json) {
    return NovelCharacter(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      gender: json['gender'] ?? '男',
      age: json['age'] ?? '',
      appearance: json['appearance'] ?? '',
      personality: (json['personality'] as List<dynamic>?)?.cast<String>() ?? [],
      role: json['role'] ?? '配角',
      faction: json['faction'] ?? '',
      abilities: (json['abilities'] as List<dynamic>?)?.cast<String>() ?? [],
      relationships: (json['relationships'] as List<dynamic>?)
              ?.map((e) => CharacterRelation.fromJson(e))
              .toList() ?? [],
      firstChapter: json['firstChapter'] ?? 0,
      keyEvents: (json['keyEvents'] as List<dynamic>?)
              ?.map((e) => CharacterEvent.fromJson(e))
              .toList() ?? [],
      currentStatus: json['currentStatus'] ?? '',
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
        'id': id, 'name': name, 'gender': gender, 'age': age,
        'appearance': appearance, 'personality': personality,
        'role': role, 'faction': faction, 'abilities': abilities,
        'relationships': relationships.map((e) => e.toJson()).toList(),
        'firstChapter': firstChapter,
        'keyEvents': keyEvents.map((e) => e.toJson()).toList(),
        'currentStatus': currentStatus, 'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  /// 获取所有关联角色名
  Set<String> get relatedNames =>
      relationships.map((r) => r.targetName).toSet();
}

const characterRoles = ['主角', '重要配角', '配角', '反派', '路人'];
const relationTypes = ['师徒', '恋人', '敌对', '朋友', '亲人', '同门', '同盟', '上下级', '其他'];

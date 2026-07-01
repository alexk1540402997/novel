import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'novel_folder_service.dart';
import '../../data/datasources/local/novel_file_service.dart';

/// 分卷大纲和章节写作目录的统一数据服务
/// 两套界面共用同一套数据逻辑
class ChapterOutlineService {
  static final ChapterOutlineService _instance = ChapterOutlineService._();
  factory ChapterOutlineService() => _instance;
  ChapterOutlineService._();

  final _fileSvc = NovelFileService();

  // ============================================================
  // 大纲文件读写
  // ============================================================

  Future<String> _outlinePath(String novelName) async {
    final base = await NovelFolderService().getNovelsFolderPath();
    return p.join(base, novelName, 'outline.json');
  }

  Future<Map<String, dynamic>> loadOutline(String novelName) async {
    final fp = await _outlinePath(novelName);
    final file = File(fp);
    if (await file.exists()) {
      return jsonDecode(await file.readAsString());
    }
    return defaultOutline();
  }

  Future<void> saveOutline(String novelName, Map<String, dynamic> data) async {
    final fp = await _outlinePath(novelName);
    await File(fp).parent.create(recursive: true);
    await File(fp).writeAsString(jsonEncode(data));
  }

  Map<String, dynamic> defaultOutline() => {
    'title': '大纲',
    'content': '',
    'children': [
      {
        'title': '全书总纲',
        'content': '在此编写全书总纲...\n\n包括：故事主线、核心冲突、世界观概述、主题思想',
        'children': [
          {'title': '大节点1', 'content': '', 'children': []},
        ],
      },
      {
        'title': '分卷大纲',
        'content': '各卷的阶段划分与主要剧情方向',
        'children': [
          {
            'title': '卷一',
            'content': '第一卷概要...',
            'children': [
              {'title': '第1章', 'content': '章节概要...', 'children': []},
            ],
          },
        ],
      },
    ],
  };

  // ============================================================
  // 路径系统
  // ============================================================

  Map<String, dynamic>? nodeAt(Map<String, dynamic> root, String p) {
    if (p.isEmpty) return root;
    var n = root;
    for (final s in p.split('/')) {
      final i = int.parse(s);
      final children = n['children'] as List? ?? [];
      if (i >= children.length) return null;
      n = children[i];
    }
    return n;
  }

  int depthOf(String p) => p.isEmpty ? 0 : p.split('/').length;

  // ============================================================
  // 自动命名
  // ============================================================

  /// 全局章节计数（分卷大纲下所有章节总数）
  int globalChapterCount(Map<String, dynamic> root) {
    final volumesNode = _volumesNode(root);
    if (volumesNode == null) return 0;
    int count = 0;
    for (final vol in (volumesNode['children'] as List? ?? [])) {
      count += (vol['children'] as List? ?? []).length;
    }
    return count;
  }

  Map<String, dynamic>? _volumesNode(Map<String, dynamic> root) {
    final children = root['children'] as List? ?? [];
    if (children.length >= 2) return children[1];
    return null;
  }

  /// parentPath 下新子节点该叫什么名字
  String autoName(Map<String, dynamic> root, String parentPath) {
    final parent = nodeAt(root, parentPath);
    final depth = depthOf(parentPath) + 1;
    final localN = (parent?['children'] as List?)?.length ?? 0;

    // 全书总纲 → 大节点N
    if (parentPath == '0') return '大节点${localN + 1}';
    // 全书总纲的子孙
    if (parentPath.startsWith('0/')) {
      if (depth == 2) return '大节点${localN + 1}';
      return '小节点${localN + 1}';
    }
    // 分卷大纲 → 卷N
    if (parentPath == '1') return '卷${_toChineseNum(localN + 1)}';
    // 分卷大纲的子孙
    if (parentPath.startsWith('1/')) {
      if (depth == 3) {
        // 章节用全局编号
        final globalN = globalChapterCount(root) + 1;
        return '第${globalN}章';
      }
      return '小节点${localN + 1}';
    }
    // 通用回退
    if (depth == 1) return '大节点${localN + 1}';
    if (depth == 2) return '第${localN + 1}章';
    return '小节点${localN + 1}';
  }

  /// 数字→中文（1-20）
  String _toChineseNum(int n) {
    const nums = ['', '一', '二', '三', '四', '五', '六', '七', '八', '九', '十',
                  '十一', '十二', '十三', '十四', '十五', '十六', '十七', '十八', '十九', '二十'];
    if (n >= 0 && n < nums.length) return nums[n];
    return '$n';
  }

  // ============================================================
  // 节点增删
  // ============================================================

  /// 添加子节点（返回新节点路径和名称）
  ({String path, String name}) addChild(Map<String, dynamic> root, String parentPath) {
    final parent = nodeAt(root, parentPath)!;
    final name = autoName(root, parentPath);
    final children = parent['children'] as List;
    children.add({'title': name, 'content': '', 'children': []});
    final newIdx = children.length - 1;
    final newPath = parentPath.isEmpty ? '$newIdx' : '$parentPath/$newIdx';
    return (path: newPath, name: name);
  }

  /// 添加同级节点
  ({String path, String name}) addSibling(Map<String, dynamic> root, String nodePath) {
    final ls = nodePath.lastIndexOf('/');
    final parentPath = ls == -1 ? '' : nodePath.substring(0, ls);
    final parent = nodeAt(root, parentPath)!;
    final name = autoName(root, parentPath);
    final children = parent['children'] as List;
    children.add({'title': name, 'content': '', 'children': []});
    final newIdx = children.length - 1;
    final newPath = parentPath.isEmpty ? '$newIdx' : '$parentPath/$newIdx';
    return (path: newPath, name: name);
  }

  /// 删除节点
  void deleteNode(Map<String, dynamic> root, String nodePath) {
    final ls = nodePath.lastIndexOf('/');
    final parentPath = ls == -1 ? '' : nodePath.substring(0, ls);
    final idx = int.parse(nodePath.substring(ls + 1));
    final parent = nodeAt(root, parentPath)!;
    (parent['children'] as List).removeAt(idx);
  }

  // ============================================================
  // 节点类型判断
  // ============================================================

  /// 节点是否可以添加子节点
  bool canAddChild(Map<String, dynamic> root, String p) {
    if (p.isEmpty) return true; // 根节点可以
    final depth = depthOf(p);
    // 全书总纲侧：大节点(depth=2)可以有子，小节点(depth≥3)不能
    if (p.startsWith('0')) {
      return depth < 3;
    }
    // 分卷大纲侧：卷(depth=2)可以有子，章节(depth=3)不能
    if (p == '1') return true; // 分卷大纲本身
    if (p.startsWith('1/')) {
      return depth == 2; // 只有卷(depth=2)可以有子节点
    }
    return depth < 2;
  }

  /// 节点是否可以添加同级
  bool canAddSibling(Map<String, dynamic> root, String p) {
    // 根节点和0/1节点不能加同级
    if (p.isEmpty || p == '0' || p == '1') return false;
    return true;
  }

  // ============================================================
  // 章节元数据
  // ============================================================

  Future<String> _metaPath(String novelName) async {
    final base = await NovelFolderService().getNovelsFolderPath();
    return p.join(base, novelName, 'chapter_meta.json');
  }

  Future<Map<int, String>> loadChapterMeta(String novelName) async {
    try {
      final f = File(await _metaPath(novelName));
      if (await f.exists()) {
        final map = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        return map.map((k, v) => MapEntry(int.parse(k), v as String));
      }
    } catch (_) {}
    return {};
  }

  Future<void> saveChapterMeta(String novelName, Map<int, String> data) async {
    try {
      final f = File(await _metaPath(novelName));
      await f.parent.create(recursive: true);
      final enc = data.map((k, v) => MapEntry(k.toString(), v));
      await f.writeAsString(jsonEncode(enc));
    } catch (_) {}
  }

  // ============================================================
  // 章节文件操作
  // ============================================================

  /// 获取章节正文
  Future<String?> readChapter(String novelName, int num) =>
      _fileSvc.readChapter(novelName, num);

  /// 保存章节正文
  Future<bool> saveChapter(String novelName, int num, String content) =>
      _fileSvc.saveChapter(novelName, num, content);

  /// 获取所有章节号
  Future<List<int>> getChapterNumbers(String novelName) =>
      _fileSvc.getChapterNumbers(novelName);

  // ============================================================
  // 全局重编号
  // ============================================================

  /// 将所有 ≥fromNum 的章节号 +delta
  Future<void> renumberChapters(String novelName, int fromNum, int delta, Map<int, String> meta) async {
    final base = await NovelFolderService().getNovelsFolderPath();
    // 文件重命名（从高到低）
    final nums = await getChapterNumbers(novelName);
    final affected = nums.where((n) => n >= fromNum).toList();
    affected.sort((a, b) => b.compareTo(a));
    for (final oldNum in affected) {
      final newNum = oldNum + delta;
      final oldF = File('$base/$novelName/chapters/chapter_$oldNum.txt');
      final newF = File('$base/$novelName/chapters/chapter_$newNum.txt');
      if (await oldF.exists()) {
        await newF.parent.create(recursive: true);
        await oldF.rename(newF.path);
      }
      if (meta.containsKey(oldNum)) {
        meta[newNum] = meta[oldNum] ?? '';
        meta.remove(oldNum);
      }
    }
    // 更新大纲中的章节标题
    try {
      final outline = await loadOutline(novelName);
      final vols = _volumesNode(outline);
      if (vols != null) {
        for (final vol in (vols['children'] as List? ?? [])) {
          for (final ch in (vol['children'] as List? ?? [])) {
            final title = ch['title'] as String? ?? '';
            final match = RegExp(r'^第(\d+)章').firstMatch(title);
            if (match != null) {
              final oldChNum = int.parse(match.group(1)!);
              if (affected.contains(oldChNum)) {
                final rest = title.substring(match.end);
                ch['title'] = '第${oldChNum + delta}章$rest';
              }
            }
          }
        }
        await saveOutline(novelName, outline);
      }
    } catch (_) {}
  }

  /// 创建新章节（在指定章节后插入，留在同一卷）
  /// 返回 (chapterNum, volumeIdx)
  Future<({int num, int? volumeIdx})> createChapter({
    required String novelName,
    required String chapterName,
    required int? afterChapterNum,
    required List<List<int>> volumeChapters, // [[1,2,3], [4,5,6]]
    required Map<int, String> meta,
  }) async {
    int newNum;
    int? targetVolumeIdx;

    if (afterChapterNum != null && volumeChapters.isNotEmpty) {
      // 找到 afterChapterNum 所在的卷
      for (var vi = 0; vi < volumeChapters.length; vi++) {
        if (volumeChapters[vi].contains(afterChapterNum)) {
          targetVolumeIdx = vi;
          break;
        }
      }
      newNum = afterChapterNum + 1;
    } else {
      // 无选中章节时：
      // - 没有任何章节：加到第一卷（index 0）
      // - 已有章节：加到最后一卷末尾
      int lastNum = 0;
      bool hasAnyChapter = false;
      for (var vi = 0; vi < volumeChapters.length; vi++) {
        for (final n in volumeChapters[vi]) {
          if (n > lastNum) lastNum = n;
          hasAnyChapter = true;
        }
      }
      if (hasAnyChapter) {
        targetVolumeIdx = volumeChapters.length - 1;
      } else {
        targetVolumeIdx = volumeChapters.isNotEmpty ? 0 : null; // 空章节→第一卷
      }
      newNum = lastNum == 0 ? 1 : lastNum + 1;
    }

    // 重编号
    final nums = await getChapterNumbers(novelName);
    if (nums.any((n) => n >= newNum)) {
      await renumberChapters(novelName, newNum, 1, meta);
    }

    // 创建文件
    await saveChapter(novelName, newNum, '');
    meta[newNum] = chapterName;
    await saveChapterMeta(novelName, meta);

    return (num: newNum, volumeIdx: targetVolumeIdx);
  }

  /// 在大纲中插入章节到指定卷的指定位置
  Future<void> insertChapterToOutline(String novelName, int num, String name, int? volumeIdx) async {
    final outline = await loadOutline(novelName);
    final vols = _volumesNode(outline);
    if (vols == null) return;
    final volChildren = vols['children'] as List? ?? [];
    if (volChildren.isEmpty) return;

    final vi = (volumeIdx != null && volumeIdx < volChildren.length) ? volumeIdx : volChildren.length - 1;
    final targetVol = volChildren[vi];
    final chList = targetVol['children'] as List? ?? [];

    final newEntry = {'title': '第$num章：$name', 'content': '', 'children': []};
    int insertIdx = chList.length;
    for (var i = 0; i < chList.length; i++) {
      final t = chList[i]['title'] as String? ?? '';
      final m = RegExp(r'(\d+)').firstMatch(t);
      if (m != null && int.parse(m.group(1)!) > num) {
        insertIdx = i;
        break;
      }
    }
    chList.insert(insertIdx, newEntry);
    await saveOutline(novelName, outline);
  }

  /// 创建新分卷（仅在大纲中追加，不自动创建章节）
  Future<String> createVolume({
    required String novelName,
    required String volName,
  }) async {
    final outline = await loadOutline(novelName);
    final children = outline['children'] as List? ?? [];
    // 确保有分卷大纲节点
    if (children.length < 2) {
      if (children.isEmpty) {
        children.add({'title': '全书总纲', 'content': '', 'children': []});
      }
      children.add({'title': '分卷大纲', 'content': '', 'children': []});
    }
    final volNode = children[1];
    final volList = volNode['children'] as List? ?? [];
    // 卷编号用中文数字
    final volIdx = volList.length + 1;
    final chineseNum = _toChineseNum(volIdx);
    final finalVolName = volName.isEmpty ? '卷$chineseNum' : (volName.startsWith('卷') ? volName : '卷$chineseNum：$volName');
    volList.add({'title': finalVolName, 'content': '', 'children': []});
    await saveOutline(novelName, outline);

    return finalVolName;
  }

  // ============================================================
  // 分卷结构读取（供章节写作目录使用）
  // ============================================================

  /// 从大纲构建分卷→章节映射
  List<({String title, List<int> chapterNumbers})> buildVolumeGroups(Map<String, dynamic> root) {
    final groups = <({String title, List<int> chapterNumbers})>[];
    final vols = _volumesNode(root);
    if (vols == null) return groups;
    for (final vol in (vols['children'] as List? ?? [])) {
      final title = vol['title'] as String? ?? '';
      final chapters = <int>[];
      for (final ch in (vol['children'] as List? ?? [])) {
        final t = ch['title'] as String? ?? '';
        final match = RegExp(r'(\d+)').firstMatch(t);
        if (match != null) {
          chapters.add(int.parse(match.group(1)!));
        }
      }
      groups.add((title: title, chapterNumbers: chapters));
    }
    return groups;
  }

  // ============================================================
  // 命名弹窗（统一组件，供大纲和目录复用）
  // ============================================================

  /// 显示章节命名弹窗
  Future<String?> showChapterNameDialog(BuildContext context) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建章节'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(hintText: '输入章节名称', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          Text('直接点击确认则章节名显示"待定"', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim().isEmpty ? '待定' : ctrl.text.trim()), child: const Text('确认')),
        ],
      ),
    );
  }

  /// 显示分卷命名弹窗
  Future<String?> showVolumeNameDialog(BuildContext context, {String defaultName = ''}) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建分卷'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: ctrl,
            autofocus: true,
            decoration: InputDecoration(hintText: defaultName.isNotEmpty ? '默认：$defaultName' : '输入分卷名称', border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          Text('直接点击确认则使用默认名称', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim().isEmpty ? (defaultName.isNotEmpty ? defaultName : '未命名') : ctrl.text.trim()), child: const Text('确认')),
        ],
      ),
    );
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../../data/datasources/local/novel_file_service.dart';
import '../services/novel_folder_service.dart';

/// 小说导出服务 — 支持 TXT / Markdown / EPUB（预留）
class ExportService {
  final _fileSvc = NovelFileService();

  /// 导出为 TXT 格式
  Future<String> exportAsTxt(String novelFolder) async {
    final chapters = await _fileSvc.getChapterNumbers(novelFolder);
    final buf = StringBuffer();
    for (final num in chapters) {
      final content = await _fileSvc.readChapter(novelFolder, num);
      if (content != null && content.trim().isNotEmpty) {
        buf.writeln('第${num}章');
        buf.writeln('=' * 40);
        buf.writeln(content);
        buf.writeln();
        buf.writeln();
      }
    }
    return buf.toString();
  }

  /// 导出为 Markdown 格式
  Future<String> exportAsMarkdown(String novelFolder) async {
    final chapters = await _fileSvc.getChapterNumbers(novelFolder);
    final buf = StringBuffer();
    buf.writeln('# 小说导出');
    buf.writeln();
    for (final num in chapters) {
      final content = await _fileSvc.readChapter(novelFolder, num);
      if (content != null && content.trim().isNotEmpty) {
        buf.writeln('## 第${num}章');
        buf.writeln();
        // 将正文按段落分割，每个段落加空行
        for (final para in content.split('\n')) {
          final trimmed = para.trim();
          if (trimmed.isNotEmpty) {
            buf.writeln(trimmed);
            buf.writeln();
          }
        }
        buf.writeln('---');
        buf.writeln();
      }
    }
    return buf.toString();
  }

  /// 导出到文件（返回文件路径）
  Future<String?> exportToFile(
    String novelFolder,
    String novelName,
    String format, // 'txt' or 'md'
  ) async {
    try {
      String content;
      String ext;
      if (format == 'txt') {
        content = await exportAsTxt(novelFolder);
        ext = 'txt';
      } else {
        content = await exportAsMarkdown(novelFolder);
        ext = 'md';
      }

      // 保存到小说文件夹中
      final basePath = await NovelFolderService().getNovelsFolderPath();
      final exportDir = Directory(path.join(basePath, '_exports'));
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${novelName}_导出_$timestamp.$ext';
      final file = File(path.join(exportDir.path, fileName));
      await file.writeAsString(content, encoding: utf8);
      return file.path;
    } catch (e) {
      return null;
    }
  }

  /// 获取导出目录路径
  Future<String> getExportDir() async {
    final basePath = await NovelFolderService().getNovelsFolderPath();
    final exportDir = Directory(path.join(basePath, '_exports'));
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    return exportDir.path;
  }
}

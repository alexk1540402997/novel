import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import '../../utils/config_service.dart';
import '../../domain/services/novel_folder_service.dart';
import '../../domain/usecases/llm_usecase.dart';
import 'logger_service.dart';

/// AI图片生成服务 — 根据文本描述生成场景插图
class ImageGenerationService {
  static final ImageGenerationService _instance = ImageGenerationService._();
  factory ImageGenerationService() => _instance;
  ImageGenerationService._();

  /// 根据场景文本生成插图（自动优化提示词）
  Future<String?> generateSceneImage({
    required String sceneText,
    required String novelName,
    int? chapterNum,
  }) async {
    // 1. 用LLM优化图片提示词
    String imagePrompt;
    try {
      final llm = LLMUseCase();
      final config = ConfigService().getAll();
      final llmName = config?['choose_configs']?['final_chapter_llm'] ?? 'Claude Sonnet 4.6';
      final optPrompt = '''将以下小说场景描述转化为图片生成提示词（用英文，80词以内）：

$sceneText

要求：包含Chinese illustration/animation style、具体场景和人物动作、氛围描述。直接输出提示词：''';
      imagePrompt = await llm.generateText(optPrompt, llmName);
      imagePrompt = imagePrompt.trim();
    } catch (_) {
      imagePrompt = sceneText.length > 500 ? sceneText.substring(0, 500) : sceneText;
    }

    // 2. 调用图片生成API
    final config = ConfigService().getAll();
    final llmConfigs = config?['llm_configs'] as Map<String, dynamic>?;
    final imageConfigName = config?['choose_configs']?['image_llm'];
    Map<String, dynamic>? apiConfig;
    if (imageConfigName != null && llmConfigs != null) {
      apiConfig = llmConfigs[imageConfigName] as Map<String, dynamic>?;
    }
    apiConfig ??= llmConfigs?.values.firstOrNull as Map<String, dynamic>?;

    if (apiConfig == null) {
      throw Exception('请先在大模型设置中配置API');
    }

    final apiKey = apiConfig['api_key'] ?? '';
    var baseUrl = (apiConfig['base_url'] ?? '').toString();
    if (!apiKey.isNotEmpty || !baseUrl.isNotEmpty) {
      throw Exception('API密钥或Base URL未配置');
    }

    // 尝试 OpenAI DALL-E 兼容接口
    if (baseUrl.endsWith('/')) baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    final url = '$baseUrl/images/generations';

    // 使用配置中的图片模型名称，默认 dall-e-3
    final modelName = apiConfig['image_model'] ?? apiConfig['model'] ?? 'dall-e-3';
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': modelName,
          'prompt': imagePrompt,
          'n': 1,
          'size': '1024x1024',
        }),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final dataItems = data['data'] as List?;
        if (dataItems != null && dataItems.isNotEmpty) {
          final item = dataItems[0];
          // 支持两种返回格式：b64_json 和 url
          final b64 = item['b64_json'] as String?;
          if (b64 != null && b64.isNotEmpty) {
            return await _saveImageFromBase64(b64, novelName, chapterNum ?? 0);
          }
          final imageUrl = item['url'] as String?;
          if (imageUrl != null && imageUrl.isNotEmpty) {
            return await _saveImageFromUrl(imageUrl, novelName, chapterNum ?? 0);
          }
        }
        throw Exception('API返回数据格式异常: ${response.body}');
      }
      throw Exception('API错误 ${response.statusCode}: ${response.body}');
    } catch (e) {
      LoggerService().logError('Image generation failed: $e');
      rethrow;
    }
  }

  /// 从URL下载图片并保存
  Future<String> _saveImageFromUrl(String imageUrl, String novelName, int chapterNum) async {
    final response = await http.get(Uri.parse(imageUrl)).timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) {
      throw Exception('下载图片失败: HTTP ${response.statusCode}');
    }
    final basePath = await NovelFolderService().getNovelsFolderPath();
    final imgDir = Directory(path.join(basePath, novelName, 'images'));
    if (!await imgDir.exists()) await imgDir.create(recursive: true);
    final fileName = 'ch${chapterNum}_${DateTime.now().millisecondsSinceEpoch}.png';
    final file = File(path.join(imgDir.path, fileName));
    await file.writeAsBytes(response.bodyBytes);
    LoggerService().logInfo('Image saved from URL: ${file.path}');
    return file.path;
  }

  /// 保存Base64图片到小说目录
  Future<String> _saveImageFromBase64(String b64Data, String novelName, int chapterNum) async {
    final basePath = await NovelFolderService().getNovelsFolderPath();
    final imgDir = Directory(path.join(basePath, novelName, 'images'));
    if (!await imgDir.exists()) await imgDir.create(recursive: true);
    final fileName = 'ch${chapterNum}_${DateTime.now().millisecondsSinceEpoch}.png';
    final file = File(path.join(imgDir.path, fileName));
    await file.writeAsBytes(base64Decode(b64Data));
    LoggerService().logInfo('Image saved: ${file.path}');
    return file.path;
  }

  /// 获取小说的所有已生成图片
  Future<List<File>> getImages(String novelName) async {
    final basePath = await NovelFolderService().getNovelsFolderPath();
    final imgDir = Directory(path.join(basePath, novelName, 'images'));
    if (!await imgDir.exists()) return [];
    return imgDir.listSync().whereType<File>().where((f) => f.path.endsWith('.png')).toList();
  }
}

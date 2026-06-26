import '../../data/models/llm_config.dart';
import '../../data/datasources/remote/llm_client.dart';
import '../../utils/config_service.dart';
import '../services/logger_service.dart';

class LLMService {
  static final LLMService _instance = LLMService._internal();
  factory LLMService() => _instance;
  LLMService._internal();

  final LLMClient _client = LLMClient();

  /// 根据配置名称获取LLM配置
  LLMConfig? _getLLMConfig(String configName) {
    try {
      final config = ConfigService().getAll();
      if (config != null && 
          config.containsKey('llm_configs') && 
          config['llm_configs'] is Map &&
          (config['llm_configs'] as Map).containsKey(configName)) {
        
        final llmConfig = (config['llm_configs'] as Map)[configName];
        if (llmConfig is Map<String, dynamic>) {
          return LLMConfig.fromJson(configName, llmConfig);
        }
      }
      LoggerService().logWarning('LLM config not found for: $configName');
      return null;
    } catch (e) {
      LoggerService().logError('Error getting LLM config for $configName: $e');
      return null;
    }
  }

  /// 调用LLM并返回结果
  Future<String> callLLM(String prompt, String configName) async {
    LoggerService().logInfo('Calling LLM with prompt config: $configName');
    final config = _validateConfig(configName);
    return await _client.callLLM(prompt, config);
  }

  /// 流式调用LLM
  Stream<String> callLLMStream(String prompt, String configName) async* {
    LoggerService().logInfo('Streaming LLM with config: $configName');
    final config = _validateConfig(configName);
    yield* _client.callLLMStream(prompt, config);
  }

  /// 验证并获取配置
  LLMConfig _validateConfig(String configName) {
    final config = _getLLMConfig(configName);
    if (config == null) {
      throw Exception('LLM配置未找到: $configName');
    }
    if (config.apiKey.isEmpty) {
      throw Exception('请先设置API密钥: $configName');
    }
    if (config.baseUrl.isEmpty) {
      throw Exception('请先设置API地址: $configName');
    }
    return config;
  }
}
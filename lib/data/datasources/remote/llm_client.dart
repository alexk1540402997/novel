import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../models/llm_config.dart';
import '../../../domain/services/logger_service.dart';

class LLMClient {
  static const int maxRetries = 3;
  static const int retryDelayMs = 1000;

  /// 调用LLM API（非流式）
  Future<String> callLLM(String prompt, LLMConfig config) async {
    LoggerService().logInfo(
        'Calling LLM: ${config.name} [${config.interfaceFormat}] model: ${config.modelName}');

    final requestBody = _buildRequestBody(prompt, config);
    return _sendRequestWithRetry(config, requestBody);
  }

  /// 流式调用LLM API
  Stream<String> callLLMStream(String prompt, LLMConfig config) async* {
    LoggerService().logInfo(
        'Streaming LLM: ${config.name} [${config.interfaceFormat}] model: ${config.modelName}');

    final requestBody = _buildRequestBody(prompt, config);
    if (config.interfaceFormat == 'Anthropic') {
      yield* _streamAnthropic(config, requestBody['messages']);
    } else {
      yield* _streamOpenAI(config, requestBody);
    }
  }

  /// 构建请求体（根据接口格式）
  dynamic _buildRequestBody(String prompt, LLMConfig config) {
    if (config.interfaceFormat == 'Anthropic') {
      return {
        'model': config.modelName,
        'max_tokens': config.maxTokens,
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
      };
    } else {
      // OpenAI兼容格式
      return {
        'model': config.modelName,
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
        'temperature': config.temperature,
        'max_tokens': config.maxTokens,
      };
    }
  }

  /// 带重试的请求
  Future<String> _sendRequestWithRetry(
      LLMConfig config, dynamic requestBody) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        return await _sendRequest(config, requestBody);
      } catch (e) {
        attempts++;
        LoggerService().logWarning('LLM request failed (attempt $attempts): $e');
        if (attempts >= maxRetries) {
          LoggerService()
              .logError('LLM request failed after $maxRetries attempts: $e');
          rethrow;
        }
        await Future.delayed(Duration(milliseconds: retryDelayMs * attempts));
      }
    }
    throw Exception(
        'Failed to get response from LLM after $maxRetries attempts');
  }

  /// 发送请求
  Future<String> _sendRequest(
      LLMConfig config, dynamic requestBody) async {
    if (config.interfaceFormat == 'Anthropic') {
      return _callAnthropicAPI(config, requestBody['messages']);
    } else {
      return _callOpenAIAPI(config, requestBody);
    }
  }

  // ===== OpenAI兼容API（DeepSeek/GPT/Gemini等） =====
  Future<String> _callOpenAIAPI(
      LLMConfig config, Map<String, dynamic> requestBody) async {
    final url = '${config.baseUrl}/chat/completions';
    final client = http.Client();
    try {
      final response = await client.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${config.apiKey}',
        },
        body: jsonEncode(requestBody),
      ).timeout(Duration(seconds: config.timeout));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return jsonResponse['choices'][0]['message']['content'];
      } else {
        LoggerService()
            .logError('OpenAI API error: ${response.statusCode} ${response.body}');
        throw Exception(
            'OpenAI API error: ${response.statusCode} ${response.body}');
      }
    } on TimeoutException catch (e) {
      LoggerService().logError('Request timeout: $e');
      throw Exception('请求超时，请检查网络或增加超时时间');
    } on SocketException catch (e) {
      LoggerService().logError('Network error: $e');
      throw Exception('网络连接失败，请检查网络或API地址');
    } finally {
      client.close();
    }
  }

  /// OpenAI流式
  Stream<String> _streamOpenAI(
      LLMConfig config, Map<String, dynamic> requestBody) async* {
    requestBody['stream'] = true;
    final url = '${config.baseUrl}/chat/completions';
    final client = http.Client();

    try {
      final request = http.Request('POST', Uri.parse(url));
      request.headers['Content-Type'] = 'application/json';
      request.headers['Authorization'] = 'Bearer ${config.apiKey}';
      request.body = jsonEncode(requestBody);

      final streamedResponse =
          await client.send(request).timeout(Duration(seconds: config.timeout));

      await for (final chunk in streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (chunk.startsWith('data: ')) {
          final data = chunk.substring(6);
          if (data == '[DONE]') break;
          try {
            final json = jsonDecode(data);
            final content = json['choices']?[0]?['delta']?['content'];
            if (content != null && content.isNotEmpty) {
              yield content;
            }
          } catch (_) {}
        }
      }
    } on TimeoutException catch (e) {
      LoggerService().logError('Stream timeout: $e');
      throw Exception('请求超时');
    } on SocketException catch (e) {
      LoggerService().logError('Stream network error: $e');
      throw Exception('网络连接失败');
    } finally {
      client.close();
    }
  }

  // ===== Anthropic原生API =====
  Future<String> _callAnthropicAPI(
      LLMConfig config, List<Map<String, dynamic>> messages) async {
    final url = '${config.baseUrl}/v1/messages';
    final client = http.Client();
    try {
      final body = <String, dynamic>{
        'model': config.modelName,
        'max_tokens': config.maxTokens,
        'messages': messages,
      };

      final response = await client.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': config.apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode(body),
      ).timeout(Duration(seconds: config.timeout));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final content = jsonResponse['content'] as List;
        // 提取第一个text类型的内容
        for (final block in content) {
          if (block['type'] == 'text') {
            return block['text'];
          }
        }
        throw Exception('No text content in Anthropic response');
      } else {
        LoggerService()
            .logError('Anthropic API error: ${response.statusCode} ${response.body}');
        throw Exception(
            'Anthropic API error: ${response.statusCode} ${response.body}');
      }
    } on TimeoutException catch (e) {
      LoggerService().logError('Anthropic timeout: $e');
      throw Exception('请求超时，请检查网络');
    } on SocketException catch (e) {
      LoggerService().logError('Anthropic network error: $e');
      throw Exception('网络连接失败，请检查API地址');
    } finally {
      client.close();
    }
  }

  /// Anthropic流式
  Stream<String> _streamAnthropic(
      LLMConfig config, List<Map<String, dynamic>> messages) async* {
    final url = '${config.baseUrl}/v1/messages';
    final client = http.Client();

    try {
      final body = <String, dynamic>{
        'model': config.modelName,
        'max_tokens': config.maxTokens,
        'messages': messages,
        'stream': true,
      };

      final request = http.Request('POST', Uri.parse(url));
      request.headers['Content-Type'] = 'application/json';
      request.headers['x-api-key'] = config.apiKey;
      request.headers['anthropic-version'] = '2023-06-01';
      request.body = jsonEncode(body);

      final streamedResponse =
          await client.send(request).timeout(Duration(seconds: config.timeout));

      await for (final chunk in streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (chunk.startsWith('data: ')) {
          final data = chunk.substring(6);
          try {
            final json = jsonDecode(data);
            if (json['type'] == 'content_block_delta') {
              final text = json['delta']?['text'];
              if (text != null && text.isNotEmpty) {
                yield text;
              }
            }
          } catch (_) {}
        }
      }
    } on TimeoutException catch (e) {
      LoggerService().logError('Anthropic stream timeout: $e');
      throw Exception('请求超时');
    } on SocketException catch (e) {
      LoggerService().logError('Anthropic stream network error: $e');
      throw Exception('网络连接失败');
    } finally {
      client.close();
    }
  }
}

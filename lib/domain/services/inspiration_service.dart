import 'package:flutter/material.dart';
import '../../domain/usecases/llm_usecase.dart';
import '../../utils/config_service.dart';

/// 灵感缓存条目
class _InspirationCache {
  final List<String> ideas;
  final DateTime timestamp;
  _InspirationCache(this.ideas) : timestamp = DateTime.now();
}

/// 灵感服务：管理本地缓存、格式化清理、统一UI
class InspirationService {
  static final InspirationService _instance = InspirationService._();
  factory InspirationService() => _instance;
  InspirationService._();

  final Map<String, _InspirationCache> _cache = {};

  /// 显示灵感对话框（自动缓存/刷新/加载状态）
  /// [emptyFallback]：当contextData为空时，提供替换描述（如"玄幻小说世界观"）
  Future<void> showInspirationDialog({
    required BuildContext context,
    required String cacheKey,        // 缓存键（如 'worldbook_all', 'character_item_3'）
    required String contextData,     // 发送给LLM的上下文
    required String promptPrefix,    // LLM提示词前缀
    required String dialogTitle,     // 对话框标题
    String emptyFallback = '',       // 空上下文时的回退描述（3.2需求）
  }) async {
    // 构建有效上下文（空上下文时使用回退描述）
    final effectiveContext = contextData.trim().isEmpty
        ? (emptyFallback.isNotEmpty ? emptyFallback : '暂无具体内容，请根据常见网文创作模式提供灵感')
        : contextData;

    // 检查缓存
    final cached = _cache[cacheKey];
    List<String> ideas = cached?.ideas ?? [];
    final hasCache = ideas.isNotEmpty;

    await showDialog(
      context: context,
      builder: (ctx) => _InspirationDialog(
        initialIdeas: ideas,
        hasCache: hasCache,
        dialogTitle: dialogTitle,
        onRefresh: () async {
          final config = ConfigService().getAll();
          final llmName = config?['choose_configs']?['final_chapter_llm'] ?? 'Claude Sonnet 4.6';
          final prompt = '$promptPrefix（用"---"分隔每条建议，不要使用**、##等Markdown符号，用纯文本）：\n\n$effectiveContext';
          final result = await LLMUseCase().generateText(prompt, llmName);
          final raw = result.split('---').map((e) => _cleanFormat(e.trim())).where((e) => e.isNotEmpty).toList();
          _cache[cacheKey] = _InspirationCache(raw);
          return raw;
        },
      ),
    );
  }

  /// 清理LLM输出中的Markdown格式
  static String _cleanFormat(String text) {
    return text
        .replaceAll(RegExp(r'\*\*'), '')
        .replaceAll(RegExp(r'##+\s*'), '')
        .replaceAll(RegExp(r'^\d+[\.\、]\s*'), '')
        .replaceAll(RegExp(r'[-*]\s+'), '')
        .trim();
  }
}

/// 灵感对话框组件
class _InspirationDialog extends StatefulWidget {
  final List<String> initialIdeas;
  final bool hasCache;
  final String dialogTitle;
  final Future<List<String>> Function() onRefresh;

  const _InspirationDialog({
    required this.initialIdeas,
    required this.hasCache,
    required this.dialogTitle,
    required this.onRefresh,
  });

  @override State<_InspirationDialog> createState() => _InspirationDialogState();
}

class _InspirationDialogState extends State<_InspirationDialog> {
  late List<String> _ideas;
  bool _loading = false;

  @override void initState() {
    super.initState();
    _ideas = widget.initialIdeas;
    // 3.1需求：无缓存时自动触发生成
    if (!widget.hasCache) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    }
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final newIdeas = await widget.onRefresh();
      setState(() { _ideas = newIdeas; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.lightbulb, color: Colors.orange),
        const SizedBox(width: 8),
        Expanded(child: Text(widget.dialogTitle)),
        if (!_loading)
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: '重新生成',
            onPressed: _refresh,
          ),
      ]),
      content: SizedBox(
        width: 520,
        child: _loading
          ? const Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(height: 40),
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('灵感生成中，请稍候...', style: TextStyle(fontSize: 14, color: Colors.grey)),
              SizedBox(height: 8),
              Text('正在连接大模型分析上下文', style: TextStyle(fontSize: 12, color: Colors.grey)),
              SizedBox(height: 40),
            ])
          : _ideas.isEmpty
            ? const Center(child: Text('点击刷新按钮生成灵感'))
            : ListView.builder(
                shrinkWrap: true,
                itemCount: _ideas.length,
                itemBuilder: (_, i) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 28, height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: Colors.orange[100], shape: BoxShape.circle),
                        child: Text('${i+1}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.orange[800])),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_ideas[i], style: const TextStyle(fontSize: 13, height: 1.6))),
                    ]),
                  ),
                ),
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭')),
      ],
    );
  }
}

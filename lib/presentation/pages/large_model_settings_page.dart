import 'package:flutter/material.dart';
import '../../app/localizations/app_localizations.dart';
import '../../utils/config_service.dart';
import '../../domain/usecases/llm_usecase.dart';
import '../../domain/usecases/embedding_usecase.dart';

class LargeModelSettingsPage extends StatefulWidget {
  const LargeModelSettingsPage({super.key});

  @override
  State<LargeModelSettingsPage> createState() => _LargeModelSettingsPageState();
}

class _LargeModelSettingsPageState extends State<LargeModelSettingsPage> {
  Map<String, dynamic> _llmConfigs = {};
  Map<String, dynamic> _embeddingConfigs = {};
  Map<String, dynamic> _chooseConfigs = {};

  @override
  void initState() {
    super.initState();
    // 初始化时加载配置
    _loadConfig();
  }

  /// 加载配置
  Future<void> _loadConfig() async {
    final config = ConfigService().getAll();
    if (config != null) {
      setState(() {
        _llmConfigs = Map<String, dynamic>.from(config['llm_configs'] ?? {});
        _embeddingConfigs = Map<String, dynamic>.from(
          config['embedding_configs'] ?? {},
        );
        _chooseConfigs = Map<String, dynamic>.from(config['choose_configs'] ?? {});
      });
    }
  }

  /// 保存配置
  Future<void> _saveConfig(
    String configType,
    String configName,
    Map<String, dynamic> configData,
  ) async {
    final key = '$configType.$configName';
    await ConfigService().set(key, configData);

    if (!mounted) return;

    final localizations = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(localizations.translate('config_saved')),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // 重新加载配置以反映更改
    _loadConfig();
  }

  /// 删除配置
  Future<void> _deleteConfig(String configType, String configName) async {
    final localizations = AppLocalizations.of(context);

    // 确认删除操作
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(localizations.translate('confirm_delete')),
          content: Text(
            localizations.translateWithArgs('confirm_delete_message', [
              configName,
            ]),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(localizations.translate('cancel')),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: Text(localizations.translate('delete')),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      // 从配置中删除
      final config = ConfigService().getAll();
      if (config != null && config[configType] != null) {
        final configs = Map<String, dynamic>.from(config[configType]);
        configs.remove(configName);
        await ConfigService().set(configType, configs);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations.translateWithArgs('config_deleted', [configName]),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );

        // 重新加载配置以反映更改
        _loadConfig();
      }
    }
  }

  /// 显示配置编辑对话框
  Future<void> _showConfigDialog({
    String? configType,
    String? configName,
    Map<String, dynamic>? configData,
  }) async {
    final localizations = AppLocalizations.of(context);

    // 控制器用于表单输入
    final nameController = TextEditingController(text: configName);
    final apiKeyController = TextEditingController(
      text: configData?['api_key'] ?? '',
    );
    final baseUrlController = TextEditingController(
      text: configData?['base_url'] ?? '',
    );
    final modelNameController = TextEditingController(
      text: configData?['model_name'] ?? '',
    );
    final temperatureController = TextEditingController(
      text: (configData?['temperature'] ?? 0.7).toString(),
    );
    final maxTokensController = TextEditingController(
      text: (configData?['max_tokens'] ?? 8192).toString(),
    );
    final timeoutController = TextEditingController(
      text: (configData?['timeout'] ?? 600).toString(),
    );

    // 接口格式下拉框的当前值
    String selectedInterfaceFormat =
        configData?['interface_format'] ?? 'OpenAI';

    // 对于嵌入配置，还有一些额外的字段
    final retrievalKController = TextEditingController(
      text: (configData?['retrieval_k'] ?? 4).toString(),
    );

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                configName == null
                    ? localizations.translate('add_new_config')
                    : localizations.translateWithArgs('edit_config', [
                        configName,
                      ]),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: localizations.translate('config_name'),
                      ),
                      enabled: configName == null, // 只有在添加新配置时才能编辑名称
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: apiKeyController,
                      decoration: InputDecoration(
                        labelText: localizations.translate('api_key_label'),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: baseUrlController,
                      decoration: InputDecoration(
                        labelText: localizations.translate('base_url'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: modelNameController,
                      decoration: InputDecoration(
                        labelText: localizations.translate('model_name'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: temperatureController,
                      decoration: InputDecoration(
                        labelText: localizations.translate('temperature'),
                      ),
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: maxTokensController,
                      decoration: InputDecoration(
                        labelText: localizations.translate('max_tokens'),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: timeoutController,
                      decoration: InputDecoration(
                        labelText: localizations.translate('timeout'),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    // 接口格式下拉框，目前仅有OpenAI选项
                    DropdownButtonFormField<String>(
                      initialValue: selectedInterfaceFormat,
                      decoration: InputDecoration(
                        labelText: localizations.translate('interface_format'),
                        border: const OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'OpenAI',
                          child: Text('OpenAI'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedInterfaceFormat = value;
                          });
                        }
                      },
                    ),
                    // 如果是嵌入配置，显示额外字段
                    if (configType == 'embedding_configs') ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: retrievalKController,
                        decoration: InputDecoration(
                          labelText: localizations.translate('retrieval_k'),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text(localizations.translate('cancel')),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: Text(localizations.translate('save')),
                  onPressed: () async {
                    // 验证输入
                    if (nameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            localizations.translate('config_name_required'),
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    // 构建配置数据
                    final newConfigData = {
                      'api_key': apiKeyController.text,
                      'base_url': baseUrlController.text,
                      'model_name': modelNameController.text,
                      'temperature':
                          double.tryParse(temperatureController.text) ?? 0.7,
                      'max_tokens':
                          int.tryParse(maxTokensController.text) ?? 8192,
                      'timeout': int.tryParse(timeoutController.text) ?? 600,
                      'interface_format': selectedInterfaceFormat,
                    };

                    // 如果是嵌入配置，添加额外字段
                    if (configType == 'embedding_configs') {
                      newConfigData['retrieval_k'] =
                          int.tryParse(retrievalKController.text) ?? 4;
                    }

                    // 保存配置
                    await _saveConfig(
                      configType!,
                      nameController.text,
                      newConfigData,
                    );
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 测试LLM配置
  Future<void> _testLLMConfig(String configName) async {
    if (!mounted) return;
    final localizations = AppLocalizations.of(context);

    final snackBar = SnackBar(
      content: Text('正在测试 $configName ...'),
      duration: const Duration(seconds: 10),
      behavior: SnackBarBehavior.floating,
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);

    try {
      final llmUseCase = LLMUseCase();
      await llmUseCase.generateText('请回复"测试成功"两个字', configName);

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$configName 测试成功 ✅'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      // 显示详细错误
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('测试失败'),
          content: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              const Text('可能的原因：', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('1. API密钥错误或未填写'),
              const Text('2. Base URL不正确 (DeepSeek应为: https://api.deepseek.com/v1)'),
              const Text('3. 网络无法访问该API地址'),
              const Text('4. 模型名称错误'),
              const SizedBox(height: 12),
              Text('错误详情: $e', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('知道了'))],
        ),
      );
    }
  }

  /// 测试嵌入模型配置
  Future<void> _testEmbeddingConfig(String configName) async {
    if (!mounted) return;
    final localizations = AppLocalizations.of(context);

    // 显示测试中提示
    if (!mounted) return;
    final snackBar = SnackBar(
      content: Text(localizations.translate('testing_config')),
      duration: const Duration(seconds: 10),
      behavior: SnackBarBehavior.floating,
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);

    try {
      // 导入嵌入模型使用案例
      final embeddingUseCase = EmbeddingUseCase();

      // 发送测试请求
      await embeddingUseCase.generateEmbedding('test', configName);

      if (!mounted) return;
      // 显示成功消息
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.translate('test_successful')),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // 显示错误消息
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${localizations.translate('test_failed')}: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// 构建配置列表项
  Widget _buildConfigListItem(
    String configType,
    String configName,
    Map<String, dynamic> configData,
  ) {
    final localizations = AppLocalizations.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    configName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 为LLM配置和嵌入模型配置显示测试按钮
                    if (configType == 'llm_configs')
                      IconButton(
                        icon: const Icon(Icons.play_arrow),
                        onPressed: () => _testLLMConfig(configName),
                        tooltip: localizations.translate('test'),
                      )
                    else if (configType == 'embedding_configs')
                      IconButton(
                        icon: const Icon(Icons.play_arrow),
                        onPressed: () => _testEmbeddingConfig(configName),
                        tooltip: localizations.translate('test'),
                      ),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showConfigDialog(
                        configType: configType,
                        configName: configName,
                        configData: configData,
                      ),
                      tooltip: localizations.translate('edit'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _deleteConfig(configType, configName),
                      tooltip: localizations.translate('delete'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${localizations.translate('base_url')}: ${configData['base_url'] ?? ''}',
            ),
            Text(
              '${localizations.translate('model_name')}: ${configData['model_name'] ?? ''}',
            ),
            Text(
              '${localizations.translate('api_key_label')}: ${configData['api_key'] != null && configData['api_key'].toString().isNotEmpty ? '********' : localizations.translate('not_set')}',
            ),
            // 对于嵌入模型，显示额外字段
            if (configType == 'embedding_configs') ...[
              Text(
                '${localizations.translate('retrieval_k')}: ${configData['retrieval_k'] ?? 4}',
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  /// 构建模型选择下拉框
  Widget _buildModelSelector({required String label, required IconData icon, required String configKey}) {
    final currentValue = _chooseConfigs[configKey] as String?;
    final configNames = _llmConfigs.keys.toList();
    if (configKey == 'image_llm') {
      // 图片模型也从llm_configs里选（也可以用专门的image configs）
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, size: 18, color: Colors.teal),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        const SizedBox(width: 8),
        if (configNames.isEmpty)
          Text('暂无可用模型', style: TextStyle(fontSize: 12, color: Colors.grey[500]))
        else
          DropdownButton<String>(
            value: configNames.contains(currentValue) ? currentValue : null,
            hint: Text('请选择', style: TextStyle(fontSize: 12, color: Colors.red[400])),
            underline: const SizedBox(),
            style: const TextStyle(fontSize: 13, color: Colors.teal),
            items: configNames.map((name) => DropdownMenuItem(
              value: name,
              child: Text(name, style: const TextStyle(fontSize: 13)),
            )).toList(),
            onChanged: (v) async {
              if (v == null) return;
              setState(() => _chooseConfigs[configKey] = v);
              await ConfigService().set('choose_configs.$configKey', v);
            },
          ),
      ]),
    );
  }

  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== 模型选择：指定当前使用的模型 =====
            Card(
              color: Colors.teal[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [
                    Icon(Icons.touch_app, size: 20, color: Colors.teal),
                    SizedBox(width: 8),
                    Text('选择使用的模型', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 4),
                  Text('下方配置好模型后，在这里选择要使用哪个', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(height: 12),
                  // 文字模型选择
                  _buildModelSelector(
                    label: '文字模型（续写/润色/摘要/灵感）',
                    icon: Icons.text_fields,
                    configKey: 'final_chapter_llm',
                  ),
                  const Divider(),
                  // 图片模型选择
                  _buildModelSelector(
                    label: '图片模型（场景图生成）',
                    icon: Icons.image,
                    configKey: 'image_llm',
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            // LLM配置部分
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          localizations.translate('llm_configs'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () =>
                              _showConfigDialog(configType: 'llm_configs'),
                          tooltip: localizations.translate('add_new_config'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_llmConfigs.isEmpty)
                      Text(localizations.translate('no_llm_configs'))
                    else
                      ..._llmConfigs.entries.map(
                        (entry) => _buildConfigListItem(
                          'llm_configs',
                          entry.key,
                          entry.value,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 嵌入配置部分
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          localizations.translate('embedding_configs'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () => _showConfigDialog(
                            configType: 'embedding_configs',
                          ),
                          tooltip: localizations.translate('add_new_config'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_embeddingConfigs.isEmpty)
                      Text(localizations.translate('no_embedding_configs'))
                    else
                      ..._embeddingConfigs.entries.map(
                        (entry) => _buildConfigListItem(
                          'embedding_configs',
                          entry.key,
                          entry.value,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

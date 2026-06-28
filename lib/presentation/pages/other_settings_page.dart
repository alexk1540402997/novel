import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../app/app.dart';
import '../../app/localizations/app_localizations.dart';
import '../../utils/config_service.dart';
import '../../utils/webdav_service.dart';
import '../../domain/services/logger_service.dart';

class OtherSettingsPage extends StatefulWidget {
  const OtherSettingsPage({super.key});

  @override
  State<OtherSettingsPage> createState() => _OtherSettingsPageState();
}

class _OtherSettingsPageState extends State<OtherSettingsPage> {
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  Timer? _debounceTimer;

  bool _isTesting = false;
  bool _isBackuping = false;
  bool _isRestoring = false;
  String _testResult = '';
  String _backupResult = '';
  String _restoreResult = '';

  // 编辑器设置（可调节控件）
  double _fontSize = 15;
  int _autoSaveSeconds = 30;
  String _exportFormat = 'TXT';

  static const _fontSizeMin = 12.0;
  static const _fontSizeMax = 24.0;
  static const _autoSaveOptions = [15, 30, 60, 120];
  static const _exportFormatOptions = ['TXT', 'Markdown'];

  @override
  void initState() {
    super.initState();
    _loadWebDAVConfig();
    _loadEditorSettings();
  }

  /// 加载编辑器设置
  void _loadEditorSettings() {
    final config = ConfigService().getAll();
    setState(() {
      _fontSize = (config?['editor_font_size'] as num?)?.toDouble() ?? 15;
      _autoSaveSeconds = (config?['editor_auto_save_seconds'] as num?)?.toInt() ?? 30;
      _exportFormat = (config?['editor_export_format'] as String?) ?? 'TXT';
    });
  }

  /// 保存编辑器设置
  Future<void> _saveEditorSetting(String key, dynamic value) async {
    await ConfigService().set(key, value);
  }

  /// 加载WebDAV配置
  Future<void> _loadWebDAVConfig() async {
    final config = ConfigService().getAll();
    if (config != null && config.containsKey('webdav_config')) {
      final webdavConfig = config['webdav_config'];
      setState(() {
        _urlController.text = webdavConfig['webdav_url'] ?? '';
        _usernameController.text = webdavConfig['webdav_username'] ?? '';
        _passwordController.text = webdavConfig['webdav_password'] ?? '';
      });
    }
  }

  /// 保存WebDAV配置
  Future<void> saveWebDAVConfig() async {
    // 收集配置服务实例
    final configService = ConfigService();
    
    // 设置所有WebDAV配置项但不立即保存
    await configService.set('webdav_config.webdav_url', _urlController.text, saveToFile: false);
    await configService.set('webdav_config.webdav_username', _usernameController.text, saveToFile: false);
    await configService.set('webdav_config.webdav_password', _passwordController.text, saveToFile: false);
    
    // 手动触发一次保存
    await configService.set('webdav_config', configService.get('webdav_config'));
    
    LoggerService().logInfo('WebDAV configuration saved');
    
    // 显示保存成功的提示
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).translate('webdav_config_saved')),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// 防抖保存WebDAV配置
  void _debounceSaveWebDAVConfig() {
    // 取消之前的定时器
    _debounceTimer?.cancel();
    
    // 启动新的定时器
    _debounceTimer = Timer(const Duration(seconds: 3), () {
      // 检查widget是否仍然挂载
      if (mounted) {
        saveWebDAVConfig();
      }
    });
  }

  /// 测试WebDAV连接
  Future<void> _testConnection(
    AppLocalizations localizations,
    BuildContext context,
  ) async {
    if (_isTesting) return;

    setState(() {
      _isTesting = true;
      _testResult = '';
    });

    String result = '';
    bool success = false;
    try {
      // 先保存配置
      await saveWebDAVConfig();

      // 测试连接
      LoggerService().logInfo('Starting WebDAV connection test');
      success = await WebDAVService().testConnection();
      result = success
          ? localizations.translate('webdav_connection_successful')
          : localizations.translate('webdav_connection_failed');
      
      LoggerService().logInfo('WebDAV connection test result: ${success ? "successful" : "failed"}');
    } catch (e) {
      LoggerService().logError('Error during WebDAV connection test: $e');
      result = 'Error: ${e.toString()}';
    }

    // 检查widget是否仍然挂载
    if (!context.mounted) return;

    setState(() {
      _testResult = result;
      _isTesting = false;
    });
  }

  /// 备份配置到WebDAV
  Future<void> _backupConfig(
    AppLocalizations localizations,
    BuildContext context,
  ) async {
    if (_isBackuping) return;

    setState(() {
      _isBackuping = true;
      _backupResult = '';
    });

    String result = '';
    bool success = false;
    try {
      // 先保存配置
      await saveWebDAVConfig();

      // 执行备份
      LoggerService().logInfo('Starting WebDAV backup operation');
      success = await WebDAVService().backupConfig();
      result = success
          ? localizations.translate('webdav_backup_successful')
          : localizations.translate('webdav_backup_failed');
      
      LoggerService().logInfo('WebDAV backup result: ${success ? "successful" : "failed"}');
    } catch (e) {
      LoggerService().logError('Error during WebDAV backup: $e');
      result = 'Error: ${e.toString()}';
    }

    // 检查widget是否仍然挂载
    if (!context.mounted) return;

    setState(() {
      _backupResult = result;
      _isBackuping = false;
    });
  }

  /// 从WebDAV恢复配置
  Future<void> _restoreConfig(
    AppLocalizations localizations,
    BuildContext context,
  ) async {
    if (_isRestoring) return;

    setState(() {
      _isRestoring = true;
      _restoreResult = '';
    });

    String result = '';
    bool success = false;
    try {
      // 先保存配置
      await saveWebDAVConfig();

      // 确认操作
      if (!context.mounted) return;
      final shouldProceed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(localizations.translate('webdav_confirm_restore')),
          content: Text(
            localizations.translate('webdav_confirm_restore_message'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(localizations.translate('webdav_cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(localizations.translate('webdav_restore_button')),
            ),
          ],
        ),
      );

      if (shouldProceed == true) {
        // 执行恢复
        LoggerService().logInfo('Starting WebDAV restore operation');
        success = await WebDAVService().restoreConfig();
        result = success
            ? localizations.translate('webdav_restore_successful')
            : localizations.translate('webdav_restore_failed');
        
        LoggerService().logInfo('WebDAV restore result: ${success ? "successful" : "failed"}');
      }
    } catch (e) {
      LoggerService().logError('Error during WebDAV restore: $e');
      result = 'Error: ${e.toString()}';
    }

    // 检查widget是否仍然挂载
    if (!context.mounted) return;

    setState(() {
      _restoreResult = result;
      _isRestoring = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 主题设置
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(children: [
                  const Icon(Icons.brightness_6, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('深色模式', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
                  Consumer<ThemeModeProvider>(
                    builder: (ctx, tp, _) => Switch(
                      value: tp.isDark,
                      onChanged: (_) => tp.toggle(),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            // WebDAV设置部分
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.translate('webdav_backup_restore_title'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _urlController,
                      decoration: InputDecoration(
                        labelText: localizations.translate('webdav_url'),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => _debounceSaveWebDAVConfig(),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: localizations.translate('webdav_username'),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => _debounceSaveWebDAVConfig(),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: localizations.translate('webdav_password'),
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      onChanged: (_) => _debounceSaveWebDAVConfig(),
                    ),
                    SizedBox(height: 16),
                    // 按钮行 - 使用Flexible确保在小屏幕上也能正确显示
                    Row(
                      children: [
                        Flexible(
                          child: ElevatedButton(
                            onPressed: _isTesting
                                ? null
                                : () => _testConnection(localizations, context),
                            child: _isTesting
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    localizations.translate(
                                      'webdav_test_connection',
                                    ),
                                    overflow: TextOverflow.fade,
                                    softWrap: false,
                                  ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Flexible(
                          child: ElevatedButton(
                            onPressed: _isBackuping
                                ? null
                                : () => _backupConfig(localizations, context),
                            child: _isBackuping
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    localizations.translate('webdav_backup'),
                                    overflow: TextOverflow.fade,
                                    softWrap: false,
                                  ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Flexible(
                          child: ElevatedButton(
                            onPressed: _isRestoring
                                ? null
                                : () => _restoreConfig(localizations, context),
                            child: _isRestoring
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    localizations.translate('webdav_restore'),
                                    overflow: TextOverflow.fade,
                                    softWrap: false,
                                  ),
                          ),
                        ),
                      ],
                    ),
                    // 结果显示行 - 只有当有结果时才显示间距和文本
                    if (_testResult.isNotEmpty ||
                        _backupResult.isNotEmpty ||
                        _restoreResult.isNotEmpty) ...[
                      SizedBox(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_testResult.isNotEmpty)
                            Text(
                              _testResult,
                              style: TextStyle(
                                color:
                                    _testResult.contains('Error') ||
                                        _testResult.contains('失败')
                                    ? Colors.red
                                    : (_testResult.contains('成功')
                                          ? Colors.green
                                          : null),
                              ),
                            ),
                          if (_testResult.isNotEmpty &&
                              (_backupResult.isNotEmpty ||
                                  _restoreResult.isNotEmpty))
                            SizedBox(height: 8),
                          if (_backupResult.isNotEmpty)
                            Text(
                              _backupResult,
                              style: TextStyle(
                                color:
                                    _backupResult.contains('Error') ||
                                        _backupResult.contains('失败')
                                    ? Colors.red
                                    : (_backupResult.contains('成功')
                                          ? Colors.green
                                          : null),
                              ),
                            ),
                          if (_backupResult.isNotEmpty &&
                              _restoreResult.isNotEmpty)
                            SizedBox(height: 8),
                          if (_restoreResult.isNotEmpty)
                            Text(
                              _restoreResult,
                              style: TextStyle(
                                color:
                                    _restoreResult.contains('Error') ||
                                        _restoreResult.contains('失败')
                                    ? Colors.red
                                    : (_restoreResult.contains('成功')
                                          ? Colors.green
                                          : null),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // 编辑器设置
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [
                    Icon(Icons.text_fields, size: 22, color: Colors.teal),
                    SizedBox(width: 8),
                    Text('写作编辑器', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 16),
                  // 字体大小 — Slider
                  Row(children: [
                    const Icon(Icons.format_size, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    const Text('字体大小', style: TextStyle(fontSize: 14)),
                    const Spacer(),
                    Text('${_fontSize.toInt()}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ]),
                  Slider(
                    value: _fontSize,
                    min: _fontSizeMin,
                    max: _fontSizeMax,
                    divisions: (_fontSizeMax - _fontSizeMin).toInt(),
                    label: '${_fontSize.toInt()}',
                    onChanged: (v) {
                      setState(() => _fontSize = v);
                      _saveEditorSetting('editor_font_size', v.toInt());
                    },
                  ),
                  const Divider(),
                  // 自动保存间隔 — DropdownButton
                  Row(children: [
                    const Icon(Icons.timer, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    const Text('自动保存间隔', style: TextStyle(fontSize: 14)),
                    const Spacer(),
                    DropdownButton<int>(
                      value: _autoSaveOptions.contains(_autoSaveSeconds) ? _autoSaveSeconds : 30,
                      underline: const SizedBox(),
                      items: _autoSaveOptions.map((s) => DropdownMenuItem(
                        value: s,
                        child: Text('${s}秒', style: const TextStyle(fontSize: 14)),
                      )).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _autoSaveSeconds = v);
                          _saveEditorSetting('editor_auto_save_seconds', v);
                        }
                      },
                    ),
                  ]),
                  const Divider(),
                  // 默认导出格式 — DropdownButton
                  Row(children: [
                    const Icon(Icons.file_present, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    const Text('默认导出格式', style: TextStyle(fontSize: 14)),
                    const Spacer(),
                    DropdownButton<String>(
                      value: _exportFormatOptions.contains(_exportFormat) ? _exportFormat : 'TXT',
                      underline: const SizedBox(),
                      items: _exportFormatOptions.map((f) => DropdownMenuItem(
                        value: f,
                        child: Text(f, style: const TextStyle(fontSize: 14)),
                      )).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _exportFormat = v);
                          _saveEditorSetting('editor_export_format', v);
                        }
                      },
                    ),
                  ]),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            // WebDAV说明
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [
                    Icon(Icons.info_outline, size: 22, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('什么是WebDAV？', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 8),
                  Text('WebDAV可将你的小说数据备份到云盘（支持坚果云、NextCloud、群晖NAS等）。配置后使用备份/恢复功能即可在多设备间同步。',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.5)),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            // 关于
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [
                    Icon(Icons.info, size: 22),
                    SizedBox(width: 8),
                    Text('关于妙笔小说', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 8),
                  Text('版本 1.0.0 · Flutter 3.38 · Android PAD', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(height: 4),
                  Text('面向中文网文创作者的AI辅助写作工具', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }
}

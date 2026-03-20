import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_provider.dart';
import '../../services/api_service.dart';

/// 设置对话框 - 配置 API 参数
class SettingsDialog extends ConsumerStatefulWidget {
  const SettingsDialog({super.key});

  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog> {
  late TextEditingController _baseUrlController;
  late TextEditingController _modelNameController;
  late TextEditingController _systemPromptController;
  late TextEditingController _modelOutputWidthController;
  late TextEditingController _modelOutputHeightController;
  late TextEditingController _apiKeyController;

  bool _isTesting = false;
  bool? _testResult;
  String? _testMessage;

  @override
  void initState() {
    super.initState();
    final config = ref.read(appConfigProvider);
    _baseUrlController = TextEditingController(text: config.baseUrl);
    _modelNameController = TextEditingController(text: config.modelName);
    _systemPromptController = TextEditingController(text: config.systemPrompt);
    _modelOutputWidthController = TextEditingController(
      text: (config.modelOutputWidth ?? 1000).toString(),
    );
    _modelOutputHeightController = TextEditingController(
      text: (config.modelOutputHeight ?? 1000).toString(),
    );
    _apiKeyController = TextEditingController(text: config.apiKey ?? '');
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _modelNameController.dispose();
    _systemPromptController.dispose();
    _modelOutputWidthController.dispose();
    _modelOutputHeightController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  /// 测试 API 连接
  Future<void> testConnection() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
      _testMessage = null;
    });

    try {
      final apiService = ApiService();
      final success = await apiService.testConnection(
        _baseUrlController.text.trim(),
        _modelNameController.text.trim(),
        _apiKeyController.text.trim(),
      );

      setState(() {
        _isTesting = false;
        _testResult = success;
        _testMessage =
            success ? '连接成功！API 服务正常运行。' : '连接失败。请检查 API 服务是否启动，URL 是否正确。';
      });
    } catch (e) {
      setState(() {
        _isTesting = false;
        _testResult = false;
        _testMessage = '测试出错：${e.toString()}';
      });
    }
  }

  /// 保存配置
  Future<void> saveConfig() async {
    final baseUrl = _baseUrlController.text.trim();
    final modelName = _modelNameController.text.trim();
    final systemPrompt = _systemPromptController.text.trim();

    if (baseUrl.isEmpty) {
      _showError('Base URL 不能为空');
      return;
    }

    if (modelName.isEmpty) {
      _showError('模型名称不能为空');
      return;
    }

    try {
      // 解析模型输出尺寸
      double? modelOutputWidth;
      double? modelOutputHeight;

      final widthStr = _modelOutputWidthController.text.trim();
      final heightStr = _modelOutputHeightController.text.trim();

      // 如果输入为空或无效，使用默认值 1000
      if (widthStr.isNotEmpty) {
        modelOutputWidth = double.tryParse(widthStr) ?? 1000;
      } else {
        modelOutputWidth = 1000;
      }

      if (heightStr.isNotEmpty) {
        modelOutputHeight = double.tryParse(heightStr) ?? 1000;
      } else {
        modelOutputHeight = 1000;
      }

      final apiKey = _apiKeyController.text.trim();

      final newConfig = AppConfig(
        baseUrl: baseUrl,
        modelName: modelName,
        systemPrompt: systemPrompt.isNotEmpty
            ? systemPrompt
            : AppConfig.defaultSystemPrompt,
        modelOutputWidth: modelOutputWidth,
        modelOutputHeight: modelOutputHeight,
        apiKey: apiKey.isNotEmpty ? apiKey : null,
      );

      await ref.read(appConfigProvider.notifier).saveConfig(newConfig);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      _showError('保存失败：${e.toString()}');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  /// 重置为默认值
  void resetToDefaults() {
    setState(() {
      _baseUrlController.text = const AppConfig().baseUrl;
      _modelNameController.text = const AppConfig().modelName;
      _systemPromptController.text = AppConfig.defaultSystemPrompt;
      _modelOutputWidthController.text = '1000';
      _modelOutputHeightController.text = '1000';
      _apiKeyController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.settings),
          SizedBox(width: 12),
          Text('设置'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Base URL 配置
            _buildUrlField(),

            const SizedBox(height: 16),

            // 模型名称配置
            _buildModelField(),

            const SizedBox(height: 16),

            // 模型输出尺寸配置
            _buildModelOutputSizeField(),

            const SizedBox(height: 16),

            // API Key 配置
            _buildApiKeyField(),

            const SizedBox(height: 16),

            // 连接测试按钮
            _buildTestButton(),

            const SizedBox(height: 24),

            // 系统提示词配置 (可折叠)
            _buildSystemPromptSection(),
          ],
        ),
      ),
      actions: [
        // 重置按钮
        TextButton(
          onPressed: resetToDefaults,
          child: const Text('重置为默认'),
        ),

        // 取消按钮
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),

        // 保存按钮
        FilledButton(
          onPressed: saveConfig,
          child: const Text('保存'),
        ),
      ],
    );
  }

  Widget _buildUrlField() {
    return TextField(
      controller: _baseUrlController,
      decoration: const InputDecoration(
        labelText: 'Base URL',
        hintText: 'http://localhost:1234/v1',
        prefixIcon: Icon(Icons.link),
        helperText: '本地 VLM 服务的 API 地址',
        border: OutlineInputBorder(),
      ),
      autocorrect: false,
      textInputAction: TextInputAction.next,
    );
  }

  Widget _buildModelField() {
    return TextField(
      controller: _modelNameController,
      decoration: const InputDecoration(
        labelText: '模型名称',
        hintText: 'qwen3.5-0.8B',
        prefixIcon: Icon(Icons.model_training),
        helperText: '如：qwen3.5-0.8B, Qwen2.5-VL-7B, llava-v1.6-34b',
        border: OutlineInputBorder(),
      ),
      autocorrect: false,
      textInputAction: TextInputAction.next,
    );
  }

  Widget _buildModelOutputSizeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '模型输出尺寸',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '模型使用的输出尺寸（默认 1000x1000）。Qwen2.5-VL 等模型使用此尺寸。如果模型返回像素坐标，请根据实际图片尺寸调整。',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _modelOutputWidthController,
                decoration: const InputDecoration(
                  labelText: '输出宽度',
                  hintText: '1000',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _modelOutputHeightController,
                decoration: const InputDecoration(
                  labelText: '输出高度',
                  hintText: '1000',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildApiKeyField() {
    return TextField(
      controller: _apiKeyController,
      decoration: const InputDecoration(
        labelText: 'API Key (可选)',
        hintText: '输入 API Key（如果需要认证）',
        prefixIcon: Icon(Icons.vpn_key),
        helperText: '某些 LM Studio 服务或云端 API 需要认证',
        border: OutlineInputBorder(),
      ),
      obscureText: true,
      autocorrect: false,
      textInputAction: TextInputAction.next,
    );
  }

  Widget _buildTestButton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _isTesting ? null : testConnection,
          icon: _isTesting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.wifi_find),
          label: Text(_isTesting ? '测试中...' : '测试连接'),
        ),
        if (_testMessage != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _testResult == true
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _testResult == true ? Colors.green : Colors.red,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _testResult == true ? Icons.check_circle : Icons.error,
                  color: _testResult == true ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _testMessage!,
                    style: TextStyle(
                      color: _testResult == true
                          ? Colors.green.shade800
                          : Colors.red.shade800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSystemPromptSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '系统提示词 (高级)',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '用于指导 AI 模型输出格式，一般无需修改',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 150,
          child: TextField(
            controller: _systemPromptController,
            decoration: const InputDecoration(
              hintText: '系统提示词模板...',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(12),
            ),
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

/// 显示设置对话框并获取结果
Future<bool?> showSettingsDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => const SettingsDialog(),
  );
}

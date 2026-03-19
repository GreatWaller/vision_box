import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 应用配置数据模型
class AppConfig {
  /// API 基础 URL
  final String baseUrl;

  /// 模型名称
  final String modelName;

  /// 系统提示词模板
  final String systemPrompt;

  /// 模型输出的归一化尺寸（某些模型如 Qwen2.5-VL 使用固定尺寸如 1000x1000）
  /// 如果为 null，则使用实际图片尺寸
  final double? modelOutputWidth;
  final double? modelOutputHeight;

  const AppConfig({
    this.baseUrl = 'http://localhost:1234/v1',
    this.modelName = 'qwen3.5-0.8B',
    this.systemPrompt = defaultSystemPrompt,
    this.modelOutputWidth = 1000,
    this.modelOutputHeight = 1000,
  });

  /// 默认系统提示词 - 强制 JSON 输出
  static const String defaultSystemPrompt = '''You are a precise object detection assistant. 
Task: Identify objects based on the user's prompt in the provided image.
Output Format: STRICTLY valid JSON only. No markdown, no explanations.
Schema: { "boxes": [ {"label": "string", "bbox": [xmin, ymin, xmax, ymax]} ] }
Constraints:
1. Coordinates must be NORMALIZED between 0.0 and 1.0 relative to the original image dimensions.
2. Origin (0,0) is top-left.
3. If no objects found, return { "boxes": [] }.
4. Do not hallucinate coordinates.''';

  /// 复制并修改配置
  AppConfig copyWith({
    String? baseUrl,
    String? modelName,
    String? systemPrompt,
    double? modelOutputWidth,
    double? modelOutputHeight,
  }) {
    return AppConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      modelName: modelName ?? this.modelName,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      modelOutputWidth: modelOutputWidth ?? this.modelOutputWidth,
      modelOutputHeight: modelOutputHeight ?? this.modelOutputHeight,
    );
  }

  /// 从 JSON 创建配置
  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      baseUrl: json['baseUrl'] as String? ?? _defaultConfig.baseUrl,
      modelName: json['modelName'] as String? ?? _defaultConfig.modelName,
      systemPrompt: json['systemPrompt'] as String? ?? defaultSystemPrompt,
      modelOutputWidth: json['modelOutputWidth'] as double?,
      modelOutputHeight: json['modelOutputHeight'] as double?,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'baseUrl': baseUrl,
      'modelName': modelName,
      'systemPrompt': systemPrompt,
      if (modelOutputWidth != null) 'modelOutputWidth': modelOutputWidth,
      if (modelOutputHeight != null) 'modelOutputHeight': modelOutputHeight,
    };
  }

  static const _defaultConfig = AppConfig();
}

/// 配置管理器 - 使用 Riverpod StateNotifier
class AppConfigNotifier extends StateNotifier<AppConfig> {
  static const String _keyBaseUrl = 'config_base_url';
  static const String _keyModelName = 'config_model_name';
  static const String _keySystemPrompt = 'config_system_prompt';

  AppConfigNotifier() : super(const AppConfig()) {
    _loadConfig();
  }

  /// 从 SharedPreferences 加载配置
  Future<void> _loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final baseUrl = prefs.getString(_keyBaseUrl);
      final modelName = prefs.getString(_keyModelName);
      final systemPrompt = prefs.getString(_keySystemPrompt);

      state = AppConfig(
        baseUrl: baseUrl ?? const AppConfig().baseUrl,
        modelName: modelName ?? const AppConfig().modelName,
        systemPrompt: systemPrompt ?? AppConfig.defaultSystemPrompt,
      );
    } catch (e) {
      // 加载失败时使用默认配置
      state = const AppConfig();
    }
  }

  /// 保存配置到 SharedPreferences
  Future<void> saveConfig(AppConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setString(_keyBaseUrl, config.baseUrl);
      await prefs.setString(_keyModelName, config.modelName);
      await prefs.setString(_keySystemPrompt, config.systemPrompt);

      state = config;
    } catch (e) {
      throw ConfigException('保存配置失败：${e.toString()}');
    }
  }

  /// 更新 Base URL
  Future<void> updateBaseUrl(String url) async {
    final newConfig = state.copyWith(baseUrl: url);
    await saveConfig(newConfig);
  }

  /// 更新模型名称
  Future<void> updateModelName(String name) async {
    final newConfig = state.copyWith(modelName: name);
    await saveConfig(newConfig);
  }

  /// 更新系统提示词
  Future<void> updateSystemPrompt(String prompt) async {
    final newConfig = state.copyWith(systemPrompt: prompt);
    await saveConfig(newConfig);
  }

  /// 重置为默认配置
  Future<void> resetToDefaults() async {
    await saveConfig(const AppConfig());
  }
}

/// Riverpod Provider - 应用配置
final appConfigProvider = StateNotifierProvider<AppConfigNotifier, AppConfig>((ref) {
  return AppConfigNotifier();
});

/// 配置相关异常
class ConfigException implements Exception {
  final String message;
  
  ConfigException(this.message);
  
  @override
  String toString() => 'ConfigException: $message';
}

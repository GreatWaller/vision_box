import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import '../models/detection_result.dart';
import '../services/api_service.dart';
import '../services/image_service.dart';
import 'app_provider.dart';

/// 检测状态枚举
enum DetectionState {
  /// 空闲状态 - 未加载图片
  idle,

  /// 正在选择图片
  picking,

  /// 图片已加载，等待输入提示词
  imageLoaded,

  /// 正在处理检测
  processing,

  /// 检测成功，显示结果
  success,

  /// 检测失败
  error,
}

/// 检测状态数据模型
class DetectionStateData {
  /// 当前状态
  final DetectionState state;

  /// 加载的图片字节
  final Uint8List? imageBytes;

  /// 原始图片宽度（未压缩）
  final double? originalWidth;

  /// 原始图片高度（未压缩）
  final double? originalHeight;

  /// 检测结果
  final DetectionResult? result;

  /// 错误信息
  final String? errorMessage;

  /// 用户提示词
  final String? userPrompt;

  /// 处理进度文本
  final String? progressText;

  const DetectionStateData({
    this.state = DetectionState.idle,
    this.imageBytes,
    this.originalWidth,
    this.originalHeight,
    this.result,
    this.errorMessage,
    this.userPrompt,
    this.progressText,
  });

  /// 复制并修改状态
  DetectionStateData copyWith({
    DetectionState? state,
    Uint8List? imageBytes,
    double? originalWidth,
    double? originalHeight,
    DetectionResult? result,
    String? errorMessage,
    String? userPrompt,
    String? progressText,
  }) {
    return DetectionStateData(
      state: state ?? this.state,
      imageBytes: imageBytes ?? this.imageBytes,
      originalWidth: originalWidth ?? this.originalWidth,
      originalHeight: originalHeight ?? this.originalHeight,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
      userPrompt: userPrompt ?? this.userPrompt,
      progressText: progressText ?? this.progressText,
    );
  }

  /// 是否有加载的图片
  bool get hasImage => imageBytes != null;

  /// 是否有检测结果
  bool get hasResult => result != null;

  /// 是否处于错误状态
  bool get isError => state == DetectionState.error;

  /// 是否正在处理
  bool get isProcessing => state == DetectionState.processing;
}

/// 检测管理器 - 核心业务逻辑
class DetectionNotifier extends StateNotifier<DetectionStateData> {
  final Ref ref;
  final ApiService _apiService = ApiService();
  final ImageService _imageService = ImageService();

  DetectionNotifier(this.ref) : super(const DetectionStateData());

  /// 选择并加载图片
  Future<bool> pickAndLoadImage() async {
    try {
      state = state.copyWith(state: DetectionState.picking);

      // 使用完整加载流程
      final imageData = await _imageService.loadCompleteImage();

      if (imageData == null) {
        // 用户取消选择
        state = state.copyWith(state: DetectionState.idle);
        return false;
      }

      state = state.copyWith(
        state: DetectionState.imageLoaded,
        imageBytes: imageData.bytes,
        originalWidth: imageData.originalWidth, // 存储原始尺寸（用于显示）
        originalHeight: imageData.originalHeight,
        result: null,
        errorMessage: null,
      );

      return true;
    } catch (e) {
      final message =
          e is ImageException ? e.message : '加载图片失败：${e.toString()}';
      state = state.copyWith(
        state: DetectionState.error,
        errorMessage: message,
      );
      return false;
    }
  }

  /// 执行物体检测
  Future<void> detectObjects(String userPrompt) async {
    // 验证状态
    if (state.imageBytes == null ||
        state.originalWidth == null ||
        state.originalHeight == null) {
      state = state.copyWith(
        state: DetectionState.error,
        errorMessage: '请先加载图片',
      );
      return;
    }

    try {
      state = state.copyWith(
        state: DetectionState.processing,
        userPrompt: userPrompt,
        progressText: '正在连接 API...',
        errorMessage: null,
      );

      // 获取当前配置
      final config = ref.read(appConfigProvider);

      // 更新进度
      state = state.copyWith(progressText: '正在分析语义...');

      // 从加载的图片字节获取实际尺寸（可能已压缩）
      final image = img.decodeImage(state.imageBytes!);
      if (image == null) {
        throw ApiException('无法解码图片');
      }
      final processedWidth = image.width.toDouble();
      final processedHeight = image.height.toDouble();

      // 调用 API（使用处理后的尺寸）
      final result = await _apiService.detectObjects(
        baseUrl: config.baseUrl,
        modelName: config.modelName,
        systemPrompt: config.systemPrompt,
        userPrompt: userPrompt,
        imageBytes: state.imageBytes!,
        mimeType: 'image/jpeg', // Web 平台默认 MIME 类型
        imageWidth: processedWidth,
        imageHeight: processedHeight,
        modelOutputWidth: config.modelOutputWidth,
        modelOutputHeight: config.modelOutputHeight,
        apiKey: config.apiKey,
      );

      // 更新进度
      state = state.copyWith(progressText: '正在定位坐标...');

      // 检查是否有检测结果
      if (!result.hasResults) {
        state = state.copyWith(
          state: DetectionState.success,
          result: result,
          progressText: '未检测到物体',
        );
      } else {
        state = state.copyWith(
          state: DetectionState.success,
          result: result,
          progressText: '检测到 ${result.boxCount} 个物体',
        );
      }
    } on ApiException catch (e) {
      state = state.copyWith(
        state: DetectionState.error,
        errorMessage: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        state: DetectionState.error,
        errorMessage: '检测失败：${e.toString()}',
      );
    }
  }

  /// 清除当前结果 (保留图片)
  void clearResult() {
    state = DetectionStateData(
      state: DetectionState.imageLoaded,
      imageBytes: state.imageBytes,
      originalWidth: state.originalWidth,
      originalHeight: state.originalHeight,
      result: null,
      errorMessage: null,
      userPrompt: null,
      progressText: null,
    );
  }

  /// 重置所有状态
  void reset() {
    state = const DetectionStateData();
  }

  /// 清除错误
  void clearError() {
    if (state.isError) {
      state = state.copyWith(
        state:
            state.hasImage ? DetectionState.imageLoaded : DetectionState.idle,
        errorMessage: null,
      );
    }
  }
}

/// Riverpod Provider - 检测状态
final detectionProvider =
    StateNotifierProvider<DetectionNotifier, DetectionStateData>((ref) {
  return DetectionNotifier(ref);
});

/// 扩展方法：获取检测状态的中文描述
extension DetectionStateExtension on DetectionState {
  String get description {
    switch (this) {
      case DetectionState.idle:
        return '空闲';
      case DetectionState.picking:
        return '选择图片中...';
      case DetectionState.imageLoaded:
        return '图片已加载';
      case DetectionState.processing:
        return '处理中...';
      case DetectionState.success:
        return '检测完成';
      case DetectionState.error:
        return '错误';
    }
  }
}

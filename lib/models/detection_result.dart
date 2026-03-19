import 'bounding_box.dart';

/// 检测结果数据模型
/// 
/// 封装 API 返回的完整检测结果
class DetectionResult {
  /// 检测到的边界框列表
  final List<BoundingBox> boxes;
  
  /// 原始图片宽度
  final double originalWidth;
  
  /// 原始图片高度
  final double originalHeight;
  
  /// 处理时间 (毫秒)
  final Duration? processingTime;
  
  /// 模型返回的原始响应 (用于调试)
  final String? rawResponse;

  DetectionResult({
    required this.boxes,
    required this.originalWidth,
    required this.originalHeight,
    this.processingTime,
    this.rawResponse,
  });

  /// 从 JSON 创建检测结果
  /// 
  /// [jsonData] 解析后的 JSON 数据
  /// [width] 原始图片宽度
  /// [height] 原始图片高度
  factory DetectionResult.fromJson(Map<String, dynamic> jsonData, double width, double height) {
    final boxesData = jsonData['boxes'] as List? ?? [];
    final boxes = boxesData
        .whereType<Map<String, dynamic>>()
        .map((boxData) => BoundingBox.fromJson(boxData, width, height))
        .toList();
    
    return DetectionResult(
      boxes: boxes,
      originalWidth: width,
      originalHeight: height,
    );
  }

  /// 检测到的物体数量
  int get boxCount => boxes.length;
  
  /// 是否有检测结果
  bool get hasResults => boxes.isNotEmpty;
  
  /// 获取所有唯一的标签
  Set<String> get uniqueLabels => boxes.map((b) => b.label).toSet();

  @override
  String toString() {
    return 'DetectionResult(count: $boxCount, labels: ${uniqueLabels.join(", ")})';
  }
}

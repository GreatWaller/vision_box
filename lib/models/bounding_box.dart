import 'dart:ui';

/// 边界框数据模型
/// 
/// 存储归一化坐标 (0.0-1.0) 和原始图片尺寸，用于后续坐标转换
class BoundingBox {
  /// 归一化坐标：左上角 X (0.0-1.0)
  final double xMinNorm;
  
  /// 归一化坐标：左上角 Y (0.0-1.0)
  final double yMinNorm;
  
  /// 归一化坐标：右下角 X (0.0-1.0)
  final double xMaxNorm;
  
  /// 归一化坐标：右下角 Y (0.0-1.0)
  final double yMaxNorm;
  
  /// 标签文本
  final String label;
  
  /// 置信度 (可选)
  final double? confidence;
  
  /// 原始图片宽度 (用于坐标转换)
  final double originalWidth;
  
  /// 原始图片高度 (用于坐标转换)
  final double originalHeight;

  BoundingBox({
    required this.xMinNorm,
    required this.yMinNorm,
    required this.xMaxNorm,
    required this.yMaxNorm,
    required this.label,
    this.confidence,
    required this.originalWidth,
    required this.originalHeight,
  });

  /// 从归一化坐标创建 BoundingBox
  /// 
  /// [data] JSON 数据，格式：{"label": "string", "bbox": [xmin, ymin, xmax, ymax]}
  /// [width] 原始图片宽度
  /// [height] 原始图片高度
  factory BoundingBox.fromJson(Map<String, dynamic> data, double width, double height) {
    final bbox = List<double>.from(data['bbox'] as List);
    return BoundingBox(
      xMinNorm: bbox[0].clamp(0.0, 1.0),
      yMinNorm: bbox[1].clamp(0.0, 1.0),
      xMaxNorm: bbox[2].clamp(0.0, 1.0),
      yMaxNorm: bbox[3].clamp(0.0, 1.0),
      label: data['label'] as String? ?? 'unknown',
      confidence: data['confidence'] as double?,
      originalWidth: width,
      originalHeight: height,
    );
  }

  /// 获取原始像素坐标 - 左上角 X
  double get xMinPixel => xMinNorm * originalWidth;
  
  /// 获取原始像素坐标 - 左上角 Y
  double get yMinPixel => yMinNorm * originalHeight;
  
  /// 获取原始像素坐标 - 右下角 X
  double get xMaxPixel => xMaxNorm * originalWidth;
  
  /// 获取原始像素坐标 - 右下角 Y
  double get yMaxPixel => yMaxNorm * originalHeight;
  
  /// 边界框宽度 (像素)
  double get widthPixel => xMaxPixel - xMinPixel;
  
  /// 边界框高度 (像素)
  double get heightPixel => yMaxPixel - yMinPixel;

  /// 根据显示尺寸计算屏幕坐标
  /// 
  /// [displayWidth] 当前显示的图片宽度
  /// [displayHeight] 当前显示的图片高度
  ///
  /// 返回：Rect 屏幕坐标矩形
  Rect toScreenRect(double displayWidth, double displayHeight) {
    // 转换为屏幕坐标
    return Rect.fromLTWH(
      xMinNorm * displayWidth,
      yMinNorm * displayHeight,
      (xMaxNorm - xMinNorm) * displayWidth,
      (yMaxNorm - yMinNorm) * displayHeight,
    );
  }

  /// 检查点是否在边界框内 (用于点击检测)
  /// 
  /// [x] 点的 X 坐标 (归一化)
  /// [y] 点的 Y 坐标 (归一化)
  bool containsPoint(double x, double y) {
    return x >= xMinNorm && 
           x <= xMaxNorm && 
           y >= yMinNorm && 
           y <= yMaxNorm;
  }

  @override
  String toString() {
    return 'BoundingBox(label: $label, confidence: $confidence, '
           'bbox: [$xMinNorm, $yMinNorm, $xMaxNorm, $yMaxNorm])';
  }
}

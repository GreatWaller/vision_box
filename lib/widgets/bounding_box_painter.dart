import 'package:flutter/material.dart';
import '../models/bounding_box.dart';

/// 边界框绘制器 - 核心可视化组件
///
/// 使用 CustomPainter 在图片上绘制边界框
/// 关键：正确处理 InteractiveViewer 的变换矩阵，确保缩放/拖拽时边界框跟随图像
class BoundingBoxPainter extends CustomPainter {
  /// 边界框列表
  final List<BoundingBox> boxes;

  /// 原始图片尺寸（用于归一化坐标转换）
  final double originalWidth;
  final double originalHeight;

  /// 当前显示区域尺寸 (Canvas 大小)
  final Size canvasSize;

  /// 变换控制器 - 获取 InteractiveViewer 的缩放和平移信息
  final TransformationController? transformationController;

  /// 选中的边界框索引 (用于高亮)
  final int? selectedIndex;

  /// 边界框点击回调
  final Function(int index)? onBoxTap;

  /// 画笔配置
  final Color boxColor;
  final double borderWidth;
  final TextStyle labelTextStyle;
  final Color labelBackgroundColor;

  BoundingBoxPainter({
    required this.boxes,
    required this.originalWidth,
    required this.originalHeight,
    required this.canvasSize,
    this.transformationController,
    this.selectedIndex,
    this.onBoxTap,
    this.boxColor = Colors.cyan,
    this.borderWidth = 2.0,
    this.labelTextStyle = const TextStyle(
      color: Colors.white,
      fontSize: 12,
      fontWeight: FontWeight.bold,
    ),
    this.labelBackgroundColor = const Color(0xCC000000),
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (boxes.isEmpty) return;

    // 计算图片在 Canvas 中的实际显示区域（考虑 BoxFit.contain）
    final imageRect = _calculateImageRect();
    if (imageRect.isEmpty) return;

    // 获取变换矩阵
    final matrix = transformationController?.value;

    // 如果有变换，应用变换到图片区域
    final finalImageRect = (matrix != null)
        ? _applyTransform(imageRect, matrix)
        : imageRect;

    // 为每个边界框绘制
    for (int i = 0; i < boxes.length; i++) {
      _drawBoundingBox(canvas, boxes[i], i, finalImageRect);
    }
  }

  /// 计算图片在 Canvas 中的显示区域（BoxFit.contain）
  Rect _calculateImageRect() {
    if (originalWidth <= 0 || originalHeight <= 0) {
      return Rect.zero;
    }

    // 计算 BoxFit.contain 的缩放比例
    final scaleX = canvasSize.width / originalWidth;
    final scaleY = canvasSize.height / originalHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    final scaledWidth = originalWidth * scale;
    final scaledHeight = originalHeight * scale;

    // 居中放置
    final offsetX = (canvasSize.width - scaledWidth) / 2;
    final offsetY = (canvasSize.height - scaledHeight) / 2;

    return Rect.fromLTWH(offsetX, offsetY, scaledWidth, scaledHeight);
  }

  /// 应用变换到矩形
  Rect _applyTransform(Rect rect, Matrix4 matrix) {
    // 变换四个角点
    final topLeft = _transformPoint(Offset(rect.left, rect.top), matrix);
    final topRight = _transformPoint(Offset(rect.right, rect.top), matrix);
    final bottomLeft = _transformPoint(Offset(rect.left, rect.bottom), matrix);
    final bottomRight = _transformPoint(Offset(rect.right, rect.bottom), matrix);

    // 创建外接矩形 - 使用所有四个点计算最小/最大值
    final minX = [topLeft.dx, topRight.dx, bottomLeft.dx, bottomRight.dx].reduce((a, b) => a < b ? a : b);
    final maxX = [topLeft.dx, topRight.dx, bottomLeft.dx, bottomRight.dx].reduce((a, b) => a > b ? a : b);
    final minY = [topLeft.dy, topRight.dy, bottomLeft.dy, bottomRight.dy].reduce((a, b) => a < b ? a : b);
    final maxY = [topLeft.dy, topRight.dy, bottomLeft.dy, bottomRight.dy].reduce((a, b) => a > b ? a : b);

    return Rect.fromLTWH(minX, minY, maxX - minX, maxY - minY);
  }

  /// 变换点坐标
  Offset _transformPoint(Offset point, Matrix4 matrix) {
    final x = point.dx;
    final y = point.dy;

    // Matrix4 变换：x' = m[0]*x + m[4]*y + m[12]*z + m[3]
    final transformedX = matrix.storage[0] * x + matrix.storage[4] * y + matrix.storage[12];
    final transformedY = matrix.storage[1] * x + matrix.storage[5] * y + matrix.storage[13];

    return Offset(transformedX, transformedY);
  }

  /// 绘制单个边界框
  void _drawBoundingBox(
    Canvas canvas,
    BoundingBox box,
    int index,
    Rect imageDisplayRect,
  ) {
    // 计算边界框在画布上的屏幕坐标
    final screenRect = _calculateScreenRect(box, imageDisplayRect);

    // 如果矩形无效，跳过
    if (screenRect.isEmpty || screenRect.width < 1 || screenRect.height < 1) {
      return;
    }

    // 判断是否选中
    final isSelected = index == selectedIndex;

    // 绘制边框
    _drawBoxBorder(canvas, screenRect, isSelected);

    // 绘制标签背景
    _drawLabelBackground(canvas, screenRect, box.label);

    // 绘制标签文本
    _drawLabelText(canvas, screenRect, box);
  }

  /// 计算边界框的屏幕坐标矩形
  ///
  /// [box] 边界框数据（归一化坐标）
  /// [imageDisplayRect] 图片在画布上的显示区域（包含变换）
  Rect _calculateScreenRect(BoundingBox box, Rect imageDisplayRect) {
    // 使用归一化坐标直接映射到图片显示区域
    return Rect.fromLTWH(
      imageDisplayRect.left + box.xMinNorm * imageDisplayRect.width,
      imageDisplayRect.top + box.yMinNorm * imageDisplayRect.height,
      (box.xMaxNorm - box.xMinNorm) * imageDisplayRect.width,
      (box.yMaxNorm - box.yMinNorm) * imageDisplayRect.height,
    );
  }

  /// 绘制边框
  void _drawBoxBorder(Canvas canvas, Rect rect, bool isSelected) {
    final paint = Paint()
      ..color = isSelected ? Colors.yellow : boxColor
      ..strokeWidth = isSelected ? borderWidth + 1 : borderWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // 绘制矩形边框
    canvas.drawRect(rect, paint);

    // 如果选中，绘制角点标记
    if (isSelected) {
      _drawCornerMarkers(canvas, rect);
    }
  }

  /// 绘制角点标记 (选中时)
  void _drawCornerMarkers(Canvas canvas, Rect rect) {
    final markerPaint = Paint()
      ..color = Colors.yellow
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final markerLength = rect.shortestSide * 0.15; // 角点长度为边长的 15%

    // 左上角
    canvas.drawLine(
      Offset(rect.left, rect.top + markerLength),
      Offset(rect.left, rect.top),
      markerPaint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.top),
      Offset(rect.left + markerLength, rect.top),
      markerPaint,
    );

    // 右上角
    canvas.drawLine(
      Offset(rect.right, rect.top + markerLength),
      Offset(rect.right, rect.top),
      markerPaint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.top),
      Offset(rect.right - markerLength, rect.top),
      markerPaint,
    );

    // 左下角
    canvas.drawLine(
      Offset(rect.left, rect.bottom - markerLength),
      Offset(rect.left, rect.bottom),
      markerPaint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.bottom),
      Offset(rect.left + markerLength, rect.bottom),
      markerPaint,
    );

    // 右下角
    canvas.drawLine(
      Offset(rect.right, rect.bottom - markerLength),
      Offset(rect.right, rect.bottom),
      markerPaint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.bottom),
      Offset(rect.right - markerLength, rect.bottom),
      markerPaint,
    );
  }

  /// 绘制标签背景
  void _drawLabelBackground(Canvas canvas, Rect rect, String label) {
    if (label.isEmpty) return;

    // 创建文本绘制器
    final textPainter = TextPainter(
      text: TextSpan(text: label, style: labelTextStyle),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // 计算背景矩形 (标签位于框的上方)
    final padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 3);
    final bgRect = Rect.fromLTWH(
      rect.left,
      rect.top - textPainter.height - padding.vertical,
      textPainter.width + padding.horizontal,
      textPainter.height + padding.vertical,
    );

    // 确保标签不超出画布顶部
    final adjustedBgRect = bgRect.top < 0
        ? Rect.fromLTWH(
            bgRect.left,
            rect.top,
            bgRect.width,
            bgRect.height,
          )
        : bgRect;

    // 绘制背景
    final bgPaint = Paint()
      ..color = labelBackgroundColor
      ..style = PaintingStyle.fill;

    canvas.drawRect(adjustedBgRect, bgPaint);
  }

  /// 绘制标签文本
  void _drawLabelText(Canvas canvas, Rect rect, BoundingBox box) {
    if (box.label.isEmpty) return;

    // 构建标签文本
    String labelText = box.label;
    if (box.confidence != null) {
      labelText += ' ${(box.confidence! * 100).toStringAsFixed(0)}%';
    }

    final textPainter = TextPainter(
      text: TextSpan(text: labelText, style: labelTextStyle),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // 计算文本位置 (在背景矩形内)
    final padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 3);
    double textY = rect.top - textPainter.height - padding.top / 2;
    
    // 如果标签超出顶部，绘制在框内顶部
    if (textY < 0) {
      textY = rect.top + padding.top / 2;
    }

    textPainter.paint(
      canvas,
      Offset(rect.left + padding.left / 2, textY),
    );
  }

  @override
  bool shouldRepaint(BoundingBoxPainter oldDelegate) {
    // 当任何绘制参数变化时重绘
    return oldDelegate.boxes != boxes ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.canvasSize != canvasSize;
  }

  /// 检测点击是否命中某个边界框
  ///
  /// [localPosition] 点击位置 (画布坐标)
  /// [imageDisplayRect] 图片显示区域
  ///
  /// 返回：命中的边界框索引，未命中返回 null
  bool hitTest(Offset localPosition) {
    // 简化处理：这里不进行实际命中测试
    // 实际命中测试由 ImageCanvas 处理
    return false;
  }
}

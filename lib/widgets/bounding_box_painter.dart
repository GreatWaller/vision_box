import 'package:flutter/material.dart';
import '../models/bounding_box.dart';

/// 边界框绘制器 - 核心可视化组件
///
/// 使用 CustomPainter 在图片上绘制边界框
/// Canvas 尺寸已经是图片的显示区域，直接将归一化坐标映射到 Canvas
class BoundingBoxPainter extends CustomPainter {
  /// 边界框列表
  final List<BoundingBox> boxes;

  /// 当前显示区域尺寸 (Canvas 大小，等于图片显示区域)
  final Size canvasSize;

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
    required this.canvasSize,
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

    // 现在 canvasSize 就是图片的显示区域
    // 直接将归一化坐标映射到 canvas
    for (int i = 0; i < boxes.length; i++) {
      _drawBox(canvas, boxes[i], i);
    }
  }

  /// 绘制单个边界框
  void _drawBox(Canvas canvas, BoundingBox box, int index) {
    // 计算边界框在画布上的屏幕坐标
    // 现在 canvasSize 就是图片显示区域，所以直接映射
    final screenRect = Rect.fromLTWH(
      box.xMinNorm * canvasSize.width,
      box.yMinNorm * canvasSize.height,
      (box.xMaxNorm - box.xMinNorm) * canvasSize.width,
      (box.yMaxNorm - box.yMinNorm) * canvasSize.height,
    );

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
    const padding = EdgeInsets.symmetric(horizontal: 6, vertical: 3);
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
    const padding = EdgeInsets.symmetric(horizontal: 6, vertical: 3);
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
  @override
  bool hitTest(Offset localPosition) {
    // 简化处理：这里不进行实际命中测试
    // 实际命中测试由 ImageCanvas 处理
    return false;
  }
}

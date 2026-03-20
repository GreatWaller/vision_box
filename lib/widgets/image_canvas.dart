import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/bounding_box.dart';
import 'bounding_box_painter.dart';

/// 图片画布组件 - 组合 InteractiveViewer、图片和边界框绘制
/// 
/// 提供：
/// 1. 图片的双指缩放、拖拽查看
/// 2. 边界框的完美跟随 (关键功能)
/// 3. 边界框点击交互
class ImageCanvas extends StatefulWidget {
  /// 图片字节数据
  final Uint8List imageBytes;
  
  /// 原始图片宽度
  final double originalWidth;
  
  /// 原始图片高度
  final double originalHeight;
  
  /// 边界框列表
  final List<BoundingBox> boxes;
  
  /// 边界框点击回调
  final Function(BoundingBox box)? onBoxTap;

  const ImageCanvas({
    super.key,
    required this.imageBytes,
    required this.originalWidth,
    required this.originalHeight,
    required this.boxes,
    this.onBoxTap,
  });

  @override
  State<ImageCanvas> createState() => _ImageCanvasState();
}

class _ImageCanvasState extends State<ImageCanvas> {
  /// 变换控制器 - 监听 InteractiveViewer 的缩放和平移
  late final TransformationController _transformationController;

  /// 选中的边界框索引
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    
    // 监听变换变化，触发重绘
    _transformationController.addListener(_onTransformChanged);
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformChanged);
    _transformationController.dispose();
    super.dispose();
  }

  /// 变换变化时的处理
  void _onTransformChanged() {
    // 触发重绘 - CustomPainter 会检测变换变化
    setState(() {
      // 不需要改变状态，只是触发 rebuild
    });
  }

  /// 处理画布点击
  void _handleTap(TapDownDetails details, Size canvasSize) {
    if (widget.boxes.isEmpty) {
      setState(() => _selectedIndex = null);
      return;
    }

    // 计算图片显示区域（使用与 BoundingBoxPainter 相同的逻辑）
    final imageDisplayRect = _calculateImageRect(canvasSize);
    if (imageDisplayRect.isEmpty) return;

    // 获取点击位置（相对于 Stack）
    final tapPosition = details.localPosition;

    // 获取变换矩阵
    final matrix = _transformationController.value;

    // 将点击位置转换到 InteractiveViewer 的局部坐标系
    // 需要应用变换矩阵的逆变换
    final localPosition = _transformPoint(tapPosition, matrix);

    // 检查点击是否在图片区域内
    if (!imageDisplayRect.contains(localPosition)) {
      setState(() => _selectedIndex = null);
      return;
    }

    // 将点击位置转换为归一化坐标（相对于图片显示区域）
    final normX = (localPosition.dx - imageDisplayRect.left) / imageDisplayRect.width;
    final normY = (localPosition.dy - imageDisplayRect.top) / imageDisplayRect.height;

    // 检测命中
    int? hitIndex;
    for (int i = 0; i < widget.boxes.length; i++) {
      if (widget.boxes[i].containsPoint(normX, normY)) {
        hitIndex = i;
        break;
      }
    }

    setState(() {
      _selectedIndex = hitIndex;
    });

    // 触发回调
    if (hitIndex != null && widget.onBoxTap != null) {
      widget.onBoxTap!(widget.boxes[hitIndex]);
    }
  }

  /// 将点从屏幕坐标转换到局部坐标（应用变换矩阵的逆）
  Offset _transformPoint(Offset point, Matrix4 matrix) {
    // 计算逆矩阵
    final inverse = Matrix4.tryInvert(matrix);
    if (inverse == null) return point;

    final x = point.dx;
    final y = point.dy;

    // 应用逆变换
    final transformedX =
        inverse.storage[0] * x + inverse.storage[4] * y + inverse.storage[12];
    final transformedY =
        inverse.storage[1] * x + inverse.storage[5] * y + inverse.storage[13];

    return Offset(transformedX, transformedY);
  }

  /// 计算图片显示区域（BoxFit.contain）
  ///
  /// 返回：Rect 图片显示区域（相对于 Stack）
  Rect _calculateImageRect(Size canvasSize) {
    if (widget.originalWidth <= 0 || widget.originalHeight <= 0) {
      return Rect.zero;
    }

    // 计算 BoxFit.contain 的缩放比例
    final scaleX = canvasSize.width / widget.originalWidth;
    final scaleY = canvasSize.height / widget.originalHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    final scaledWidth = widget.originalWidth * scale;
    final scaledHeight = widget.originalHeight * scale;

    // 居中放置
    final offsetX = (canvasSize.width - scaledWidth) / 2;
    final offsetY = (canvasSize.height - scaledHeight) / 2;

    return Rect.fromLTWH(offsetX, offsetY, scaledWidth, scaledHeight);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);

        // 计算图片的显示区域（BoxFit.contain）
        final imageDisplayRect = _calculateImageRect(canvasSize);

        return GestureDetector(
          onTapDown: (details) => _handleTap(details, canvasSize),
          child: InteractiveViewer(
            transformationController: _transformationController,
            minScale: 0.1,
            maxScale: 10.0,
            boundaryMargin: const EdgeInsets.all(100),
            child: SizedBox(
              width: canvasSize.width,
              height: canvasSize.height,
              child: Stack(
                children: [
                  // 底层：图片显示
                  Image.memory(
                    widget.imageBytes,
                    fit: BoxFit.contain,
                    width: widget.originalWidth,
                    height: widget.originalHeight,
                    gaplessPlayback: true,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.broken_image,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '图片加载失败',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // 顶层：边界框绘制 - 使用图片的实际显示区域
                  if (widget.boxes.isNotEmpty && !imageDisplayRect.isEmpty)
                    Positioned(
                      left: imageDisplayRect.left,
                      top: imageDisplayRect.top,
                      width: imageDisplayRect.width,
                      height: imageDisplayRect.height,
                      child: CustomPaint(
                        size: Size(imageDisplayRect.width, imageDisplayRect.height),
                        painter: BoundingBoxPainter(
                          boxes: widget.boxes,
                          canvasSize: Size(imageDisplayRect.width, imageDisplayRect.height),
                          selectedIndex: _selectedIndex,
                          onBoxTap: (index) {
                            setState(() {
                              _selectedIndex = index;
                            });
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 空状态提示组件
class EmptyCanvasPlaceholder extends StatelessWidget {
  final String message;
  final VoidCallback? onPickImage;

  const EmptyCanvasPlaceholder({
    super.key,
    this.message = '请选择一张图片开始',
    this.onPickImage,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_outlined,
            size: 96,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          if (onPickImage != null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onPickImage,
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('选择图片'),
            ),
          ],
        ],
      ),
    );
  }
}

/// 加载状态指示器
class LoadingOverlay extends StatelessWidget {
  final String message;
  final bool isVisible;

  const LoadingOverlay({
    super.key,
    required this.message,
    this.isVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      strokeWidth: 4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
  
  /// 图片 Global Key - 用于获取图片实际渲染尺寸
  final _imageKey = GlobalKey();

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

  /// 获取图片在 Stack 中的显示区域
  /// 
  /// 返回：Rect 图片显示区域（相对于 Stack）
  Rect? _getImageDisplayRect() {
    final context = _imageKey.currentContext;
    if (context == null) return null;
    
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return null;
    
    // 获取图片在 Stack 中的位置和尺寸
    final position = box.localToGlobal(Offset.zero);
    return Rect.fromLTWH(
      position.dx,
      position.dy,
      box.size.width,
      box.size.height,
    );
  }

  /// 获取图片的实际显示尺寸
  /// 
  /// 返回：Size 图片尺寸
  Size? _getImageSize() {
    final context = _imageKey.currentContext;
    if (context == null) return null;
    
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return null;
    
    return box.size;
  }

  /// 处理画布点击
  void _handleTap(TapDownDetails details, Size canvasSize) {
    if (widget.boxes.isEmpty) {
      setState(() => _selectedIndex = null);
      return;
    }

    // 获取图片显示区域
    final imageDisplayRect = _calculateImageDisplayRect();
    if (imageDisplayRect == null) return;

    // 获取点击位置（相对于 Stack）
    final tapPosition = details.localPosition;
    
    // 检查点击是否在图片区域内
    if (!imageDisplayRect.contains(tapPosition)) {
      setState(() => _selectedIndex = null);
      return;
    }

    // 将点击位置转换为归一化坐标
    final normX = (tapPosition.dx - imageDisplayRect.left) / imageDisplayRect.width;
    final normY = (tapPosition.dy - imageDisplayRect.top) / imageDisplayRect.height;
    
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

  /// 计算图片显示区域
  ///
  /// 使用 GlobalKey 获取图片实际渲染尺寸
  Rect? _calculateImageDisplayRect() {
    return _getImageDisplayRect();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
        
        return GestureDetector(
          onTapDown: (details) => _handleTap(details, canvasSize),
          child: InteractiveViewer(
            transformationController: _transformationController,
            minScale: 0.1,
            maxScale: 10.0,
            boundaryMargin: const EdgeInsets.all(100),
            child: Stack(
              children: [
                // 底层：图片显示
                Image.memory(
                  widget.imageBytes,
                  key: _imageKey,
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
                
                // 顶层：边界框绘制
                if (widget.boxes.isNotEmpty)
                  CustomPaint(
                    size: canvasSize,
                    painter: BoundingBoxPainter(
                      boxes: widget.boxes,
                      originalWidth: widget.originalWidth,
                      originalHeight: widget.originalHeight,
                      canvasSize: canvasSize,
                      transformationController: _transformationController,
                      selectedIndex: _selectedIndex,
                      onBoxTap: (index) {
                        setState(() {
                          _selectedIndex = index;
                        });
                      },
                    ),
                  ),
              ],
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

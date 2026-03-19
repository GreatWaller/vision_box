import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

/// 图片服务 - 处理图片选取和元数据读取
///
/// 负责：
/// 1. 调用系统文件选择器
/// 2. 读取图片原始分辨率
/// 3. 图片压缩 (可选，用于处理超大图片)
class ImageService {
  final ImagePicker _picker = ImagePicker();

  /// 从相册选择图片
  ///
  /// 返回：XFile 对象，如果用户取消则返回 null
  Future<XFile?> pickImageFromGallery() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: null, // 不限制分辨率
        maxHeight: null,
      );
      return pickedFile;
    } catch (e) {
      throw ImageException('选择图片失败：${e.toString()}');
    }
  }

  /// 从文件选择器选择图片
  ///
  /// 返回：XFile 对象，如果用户取消则返回 null
  Future<XFile?> pickImageFromFile() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: null,
        maxHeight: null,
      );
      return pickedFile;
    } catch (e) {
      throw ImageException('选择文件失败：${e.toString()}');
    }
  }

  /// 获取图片元数据
  ///
  /// [xFile] XFile 对象
  ///
  /// 返回：(宽度，高度) 元组
  Future<(double, double)> getImageMetadataFromXFile(XFile xFile) async {
    try {
      // 使用 image 库解码图片获取元数据
      final bytes = await xFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) {
        throw ImageException('无法解码图片');
      }

      return (image.width.toDouble(), image.height.toDouble());
    } catch (e) {
      if (e is ImageException) rethrow;
      throw ImageException('读取图片元数据失败：${e.toString()}');
    }
  }

  /// 读取图片字节
  ///
  /// [xFile] XFile 对象
  ///
  /// 返回：图片原始字节数据
  Future<Uint8List> readImageBytesFromXFile(XFile xFile) async {
    try {
      return await xFile.readAsBytes();
    } catch (e) {
      throw ImageException('读取图片字节失败：${e.toString()}');
    }
  }

  /// 获取图片 MIME 类型
  ///
  /// [xFile] XFile 对象
  ///
  /// 返回：MIME 类型字符串 (如 'image/jpeg')
  String getMimeTypeFromXFile(XFile xFile) {
    // 优先使用 XFile 自带的 mimeType
    if (xFile.mimeType != null && xFile.mimeType!.isNotEmpty) {
      return xFile.mimeType!;
    }
    
    // 备用：从路径推断
    final path = xFile.path;
    if (path != null) {
      final extension = path.split('.').last.toLowerCase();
      switch (extension) {
        case 'jpg':
        case 'jpeg':
          return 'image/jpeg';
        case 'png':
          return 'image/png';
        case 'gif':
          return 'image/gif';
        case 'webp':
          return 'image/webp';
      }
    }
    return 'image/jpeg'; // 默认
  }

  /// 压缩图片 (如果需要)
  ///
  /// 当图片长边超过 [maxDimension] 时，等比压缩至该尺寸
  ///
  /// [bytes] 原始图片字节
  /// [maxDimension] 最大边长 (默认 2048)
  /// [quality] JPEG 质量 (1-100，默认 85)
  ///
  /// 返回：(压缩后的字节，压缩后宽度，压缩后高度，原始宽度，原始高度，是否压缩)
  Future<(Uint8List, double, double, double, double, bool)> compressImageIfNeeded(
    Uint8List bytes, {
    int maxDimension = 2048,
    int quality = 85,
  }) async {
    try {
      // 解码图片
      final image = img.decodeImage(bytes);
      if (image == null) {
        throw ImageException('无法解码图片');
      }

      final originalWidth = image.width.toDouble();
      final originalHeight = image.height.toDouble();

      // 检查是否需要压缩
      final maxSide = image.width > image.height ? image.width : image.height;
      if (maxSide <= maxDimension) {
        // 不需要压缩
        return (bytes, originalWidth, originalHeight, originalWidth, originalHeight, false);
      }

      // 计算缩放比例
      final scale = maxDimension / maxSide;
      final newWidth = (image.width * scale).round();
      final newHeight = (image.height * scale).round();

      // 缩放图片
      final resized = img.copyResize(
        image,
        width: newWidth,
        height: newHeight,
      );

      // 重新编码为 JPEG
      final compressed = img.encodeJpg(resized, quality: quality);

      return (
        Uint8List.fromList(compressed),
        newWidth.toDouble(),  // 压缩后宽度
        newHeight.toDouble(), // 压缩后高度
        originalWidth,        // 原始宽度
        originalHeight,       // 原始高度
        true,                 // 标记已压缩
      );
    } catch (e) {
      if (e is ImageException) rethrow;
      throw ImageException('压缩图片失败：${e.toString()}');
    }
  }

  /// 完整图片加载流程
  ///
  /// 1. 选择图片
  /// 2. 获取元数据
  /// 3. 按需压缩
  /// 4. 返回处理后的数据
  ///
  /// 返回：LoadedImageData 包含所有必要信息
  Future<LoadedImageData?> loadCompleteImage() async {
    // 选择图片
    final xFile = await pickImageFromGallery();
    if (xFile == null) {
      return null; // 用户取消
    }

    // 读取字节
    final bytes = await readImageBytesFromXFile(xFile);

    // 压缩处理
    final (compressedBytes, procWidth, procHeight, origWidth, origHeight, wasCompressed) =
        await compressImageIfNeeded(bytes);

    // 获取 MIME 类型
    final mimeType = getMimeTypeFromXFile(xFile);

    return LoadedImageData(
      bytes: compressedBytes,
      originalWidth: origWidth,
      originalHeight: origHeight,
      processedWidth: procWidth,
      processedHeight: procHeight,
      mimeType: mimeType,
      wasCompressed: wasCompressed,
      filePath: xFile.path ?? '',
    );
  }
}

/// 加载后的图片数据
class LoadedImageData {
  /// 图片字节 (可能已压缩)
  final Uint8List bytes;

  /// 原始图片宽度 (压缩前的尺寸)
  final double originalWidth;

  /// 原始图片高度 (压缩前的尺寸)
  final double originalHeight;

  /// 处理后的图片宽度 (发送给 API 的图片尺寸)
  final double processedWidth;

  /// 处理后的图片高度 (发送给 API 的图片尺寸)
  final double processedHeight;

  /// MIME 类型
  final String mimeType;

  /// 是否经过了压缩
  final bool wasCompressed;

  /// 文件路径
  final String filePath;

  LoadedImageData({
    required this.bytes,
    required this.originalWidth,
    required this.originalHeight,
    required this.processedWidth,
    required this.processedHeight,
    required this.mimeType,
    required this.wasCompressed,
    required this.filePath,
  });

  /// 如果图片被压缩过，获取缩放比例
  double get scaleRatio {
    if (!wasCompressed) return 1.0;
    return processedWidth / originalWidth;
  }
}

/// 图片相关异常
class ImageException implements Exception {
  final String message;
  
  ImageException(this.message);
  
  @override
  String toString() => 'ImageException: $message';
}

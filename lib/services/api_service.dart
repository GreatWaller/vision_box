import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../models/detection_result.dart';
import '../models/bounding_box.dart';

/// API 服务 - 处理与本地 VLM 服务的通信
///
/// 负责：
/// 1. Dio 客户端配置 (超时、拦截器)
/// 2. Base64 图片编码
/// 3. 请求构建 (OpenAI 兼容格式)
/// 4. JSON 响应清洗与解析
class ApiService {
  late final Dio _dio;

  /// 默认超时时间 (秒)
  static const int defaultTimeout = 120; // VLM 推理可能较慢

  ApiService() {
    _dio = Dio();
    _dio.options.connectTimeout = const Duration(seconds: defaultTimeout);
    _dio.options.receiveTimeout = const Duration(seconds: defaultTimeout);

    // 添加日志拦截器 (调试用)
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      error: true,
    ));
  }

  /// 测试 API 连接
  ///
  /// [baseUrl] API 基础 URL
  /// [modelName] 模型名称
  /// [apiKey] API Key（可选，用于认证）
  ///
  /// 返回：true 表示连接成功
  Future<bool> testConnection(String baseUrl, String modelName, String? apiKey) async {
    try {
      // 构建请求头
      final headers = <String, dynamic>{
        'Content-Type': 'application/json',
      };
      
      // 如果提供了 API Key，添加认证头
      if (apiKey != null && apiKey.isNotEmpty) {
        headers['Authorization'] = 'Bearer $apiKey';
      }

      final response = await _dio.post(
        '$baseUrl/chat/completions',
        data: {
          'model': modelName,
          'messages': [
            {'role': 'user', 'content': 'Hello'}
          ],
          'max_tokens': 100,
        },
        options: Options(
          headers: headers,
        ),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// 发送检测请求
  ///
  /// [baseUrl] API 基础 URL
  /// [modelName] 模型名称
  /// [systemPrompt] 系统提示词
  /// [userPrompt] 用户提示词
  /// [imageBytes] 图片字节数据
  /// [mimeType] 图片 MIME 类型 (如 'image/jpeg')
  /// [imageWidth] 图片宽度（实际显示的图片宽度）
  /// [imageHeight] 图片高度（实际显示的图片高度）
  /// [modelOutputWidth] 模型输出宽度（某些模型如 Qwen2.5-VL 使用固定尺寸如 1000）
  /// [modelOutputHeight] 模型输出高度（某些模型使用固定尺寸如 1000）
  /// [apiKey] API Key（可选，用于认证）
  ///
  /// 返回：DetectionResult 检测结果
  Future<DetectionResult> detectObjects({
    required String baseUrl,
    required String modelName,
    required String systemPrompt,
    required String userPrompt,
    required Uint8List imageBytes,
    required String mimeType,
    required double imageWidth,
    required double imageHeight,
    double? modelOutputWidth,
    double? modelOutputHeight,
    String? apiKey,
  }) async {
    final stopwatch = Stopwatch()..start();

    // 将图片转换为 Base64
    final base64Image = base64Encode(imageBytes);
    final dataUri = 'data:$mimeType;base64,$base64Image';

    // 构建请求体 (OpenAI 兼容格式)
    // 注意：某些 VLM 服务 (如 LM Studio) 不支持 response_format，
    // 我们依靠 system prompt 来指导模型输出 JSON
    final requestBody = {
      'model': modelName,
      'messages': [
        {
          'role': 'system',
          'content': systemPrompt,
        },
        {
          'role': 'user',
          'content': [
            {
              'type': 'text',
              'text': userPrompt,
            },
            {
              'type': 'image_url',
              'image_url': {
                'url': dataUri,
              },
            },
          ],
        },
      ],
      'temperature': 0.1, // 低温度确保输出稳定
      // 移除 response_format，因为不是所有服务都支持
    };

    try {
      // 构建请求头
      final headers = <String, dynamic>{
        'Content-Type': 'application/json',
      };
      
      // 如果提供了 API Key，添加认证头
      if (apiKey != null && apiKey.isNotEmpty) {
        headers['Authorization'] = 'Bearer $apiKey';
      }

      final response = await _dio.post(
        '$baseUrl/chat/completions',
        data: requestBody,
        options: Options(
          headers: headers,
        ),
      );

      stopwatch.stop();

      // 提取响应内容
      final content = _extractContent(response.data);

      // 清洗并解析 JSON
      final jsonData = _parseJsonResponse(
        content,
        imageWidth,
        imageHeight,
        modelOutputWidth,
        modelOutputHeight,
      );

      // 创建检测结果
      return DetectionResult.fromJson(
        jsonData,
        imageWidth,
        imageHeight,
      ).copyWith(
        processingTime: stopwatch.elapsed,
        rawResponse: content,
      );
    } on DioException catch (e) {
      stopwatch.stop();
      throw _handleDioError(e);
    } catch (e) {
      stopwatch.stop();
      throw ApiException('解析失败：${e.toString()}');
    }
  }

  /// 从响应中提取内容
  String _extractContent(Map<String, dynamic> responseData) {
    try {
      final choices = responseData['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        throw ApiException('响应中未找到 choices 字段');
      }

      final message = choices[0]['message'] as Map<String, dynamic>?;
      if (message == null) {
        throw ApiException('响应中未找到 message 字段');
      }

      final content = message['content'] as String?;
      if (content == null) {
        throw ApiException('响应中未找到 content 字段');
      }

      return content;
    } catch (e) {
      throw ApiException('提取响应内容失败：${e.toString()}');
    }
  }

  /// 清洗并解析 JSON 响应
  ///
  /// 处理可能的 Markdown 包裹、多余空格等
  /// 支持多种 JSON 格式：
  /// 1. {"boxes": [...]} - 标准格式
  /// 2. [...] - 数组格式
  /// 3. {"data": {"boxes": [...]}} - 嵌套格式
  ///
  /// [imageWidth] 图片宽度，用于将像素坐标转换为归一化坐标
  /// [imageHeight] 图片高度，用于将像素坐标转换为归一化坐标
  /// [modelOutputWidth] 模型输出宽度（某些模型使用固定尺寸如 1000）
  /// [modelOutputHeight] 模型输出高度（某些模型使用固定尺寸如 1000）
  Map<String, dynamic> _parseJsonResponse(String content, double imageWidth,
      double imageHeight, double? modelOutputWidth, double? modelOutputHeight) {
    try {
      // 1. 移除可能的 Markdown 代码块标记
      String cleaned = content.trim();

      // 移除 ```json ... ``` 或 ``` ... ``` 包裹（支持多行）
      // 使用更宽松的正则表达式
      final jsonMarkdown =
          RegExp(r'```\s*(?:json)?\s*([\s\S]*?)\s*```', multiLine: true);
      final match = jsonMarkdown.firstMatch(cleaned);
      if (match != null) {
        cleaned = match.group(1)!.trim();
      }

      // 如果还有 ``` 标记，再次尝试移除
      if (cleaned.startsWith('```')) {
        cleaned = cleaned.replaceAll('```', '').trim();
      }

      // 2. 移除可能的解释性前缀（仅在确实存在时）
      // 只移除常见的解释性短语，避免误伤 JSON
      final prefixes = [
        r'^(以下是|这里是|这是|结果如下|检测结果|检测到的物体|JSON 数据|JSON 结果)\s*[:：]?\s*',
        r"^(Here is|Here's|Following is|The result is|Detected objects)\s*[:.]?\s*",
      ];
      for (final prefix in prefixes) {
        cleaned =
            cleaned.replaceFirst(RegExp(prefix, caseSensitive: false), '');
      }

      // 3. 处理转义的 JSON 字符串（某些模型返回字符串形式的 JSON）
      // 例如："{\"boxes\": [...]}" 而不是 {"boxes": [...]}
      if (cleaned.startsWith('"') && cleaned.endsWith('"')) {
        // 移除外层引号并 unescape
        cleaned = cleaned.substring(1, cleaned.length - 1);
        cleaned = cleaned.replaceAll('\\"', '"');
        cleaned = cleaned.replaceAll('\\\\', '\\');
        cleaned = cleaned.replaceAll('\\n', '\n');
        cleaned = cleaned.replaceAll('\\t', '\t');
      }

      // 4. 尝试解析 JSON
      dynamic parsed = jsonDecode(cleaned);

      // 4. 适配多种 JSON 格式
      if (parsed is List) {
        // 数组格式：[{"bbox_2d": [...], "label": "..."}]
        // 转换为标准格式
        return _convertArrayFormat(parsed as List, imageWidth, imageHeight,
            modelOutputWidth, modelOutputHeight);
      }

      if (parsed is Map<String, dynamic>) {
        // 检查是否是嵌套格式
        if (parsed.containsKey('data') &&
            parsed['data'] is Map<String, dynamic>) {
          final data = parsed['data'] as Map<String, dynamic>;
          if (data.containsKey('boxes')) {
            // 转换 boxes 中的像素坐标为归一化
            return _convertBoxesFormat(data, imageWidth, imageHeight,
                modelOutputWidth, modelOutputHeight);
          }
        }

        // 检查是否有 boxes 字段
        if (parsed.containsKey('boxes')) {
          // 转换 boxes 中的像素坐标为归一化
          return _convertBoxesFormat(parsed, imageWidth, imageHeight,
              modelOutputWidth, modelOutputHeight);
        }

        // 检查是否有 detections 字段
        if (parsed.containsKey('detections')) {
          return _convertBoxesFormat({'boxes': parsed['detections']},
              imageWidth, imageHeight, modelOutputWidth, modelOutputHeight);
        }

        // 检查是否有 objects 字段
        if (parsed.containsKey('objects')) {
          return _convertBoxesFormat({'boxes': parsed['objects']}, imageWidth,
              imageHeight, modelOutputWidth, modelOutputHeight);
        }
      }

      throw ApiException('无法识别的 JSON 格式');
    } on FormatException catch (e) {
      throw ApiException('JSON 解析失败：${e.toString()}\n原始内容：$content');
    }
  }

  /// 转换 boxes 数组中的坐标为归一化格式
  ///
  /// 支持像素坐标和归一化坐标的自动检测
  Map<String, dynamic> _convertBoxesFormat(
    Map<String, dynamic> data,
    double imageWidth,
    double imageHeight,
    double? modelOutputWidth,
    double? modelOutputHeight,
  ) {
    final boxesList = data['boxes'] as List?;
    if (boxesList == null) {
      return {'boxes': <Map<String, dynamic>>[]};
    }

    final normWidth = modelOutputWidth ?? imageWidth;
    final normHeight = modelOutputHeight ?? imageHeight;
    final convertedBoxes = <Map<String, dynamic>>[];

    for (final item in boxesList) {
      if (item is Map<String, dynamic>) {
        final label = item['label'] as String? ?? 'object';
        // 提取边界框 (支持多种键名)
        List? bboxList = item['bbox'] as List? ??
            item['bbox_2d'] as List? ??
            item['box'] as List? ??
            item['coordinates'] as List?;

        if (bboxList != null && bboxList.length >= 4) {
          final x1 = (bboxList[0] as num).toDouble();
          final y1 = (bboxList[1] as num).toDouble();
          final x2 = (bboxList[2] as num).toDouble();
          final y2 = (bboxList[3] as num).toDouble();

          // 检测坐标格式：如果最大值 > 1，说明是像素坐标；否则是归一化坐标
          final isPixelCoords = x1 > 1 || y1 > 1 || x2 > 1 || y2 > 1;

          List<double> normBox;
          if (isPixelCoords) {
            // 像素坐标 -> 归一化
            normBox = [
              (x1 / normWidth).clamp(0.0, 1.0),
              (y1 / normHeight).clamp(0.0, 1.0),
              (x2 / normWidth).clamp(0.0, 1.0),
              (y2 / normHeight).clamp(0.0, 1.0),
            ];
          } else {
            // 已经是归一化坐标
            normBox = [
              x1.clamp(0.0, 1.0),
              y1.clamp(0.0, 1.0),
              x2.clamp(0.0, 1.0),
              y2.clamp(0.0, 1.0),
            ];
          }

          convertedBoxes.add({
            'label': label,
            'bbox': normBox,
            'confidence': item['confidence'] as double?,
          });
        }
      }
    }

    return {'boxes': convertedBoxes};
  }

  /// 转换数组格式的 JSON 为标准格式
  ///
  /// 支持格式：
  /// - [{"bbox_2d": [x1, y1, x2, y2], "label": "..."}]
  /// - [{"bbox": [x1, y1, x2, y2], "label": "..."}]
  /// - [{"box": [x1, y1, x2, y2], "label": "..."}]
  ///
  /// [imageWidth] 图片宽度（实际显示的图片宽度）
  /// [imageHeight] 图片高度（实际显示的图片高度）
  /// [modelOutputWidth] 模型输出宽度（某些模型如 Qwen2.5-VL 使用固定尺寸如 1000）
  /// [modelOutputHeight] 模型输出高度（某些模型使用固定尺寸如 1000）
  Map<String, dynamic> _convertArrayFormat(List array, double imageWidth,
      double imageHeight, double? modelOutputWidth, double? modelOutputHeight) {
    final boxes = <Map<String, dynamic>>[];

    // 如果指定了模型输出尺寸，使用该尺寸进行归一化；否则使用实际图片尺寸
    final normWidth = modelOutputWidth ?? imageWidth;
    final normHeight = modelOutputHeight ?? imageHeight;

    for (final item in array) {
      if (item is Map<String, dynamic>) {
        // 提取标签
        final label = item['label'] as String? ?? 'object';

        // 提取边界框 (支持多种键名)
        List? bboxList = item['bbox'] as List? ??
            item['bbox_2d'] as List? ??
            item['box'] as List? ??
            item['coordinates'] as List?;

        if (bboxList != null && bboxList.length >= 4) {
          final x1 = (bboxList[0] as num).toDouble();
          final y1 = (bboxList[1] as num).toDouble();
          final x2 = (bboxList[2] as num).toDouble();
          final y2 = (bboxList[3] as num).toDouble();

          // 检测坐标格式：如果最大值 > 1，说明是像素坐标；否则是归一化坐标
          final isPixelCoords = x1 > 1 || y1 > 1 || x2 > 1 || y2 > 1;

          List<double> normBox;
          if (isPixelCoords) {
            // 像素坐标 -> 归一化
            normBox = [
              (x1 / normWidth).clamp(0.0, 1.0),
              (y1 / normHeight).clamp(0.0, 1.0),
              (x2 / normWidth).clamp(0.0, 1.0),
              (y2 / normHeight).clamp(0.0, 1.0),
            ];
          } else {
            // 已经是归一化坐标
            normBox = [
              x1.clamp(0.0, 1.0),
              y1.clamp(0.0, 1.0),
              x2.clamp(0.0, 1.0),
              y2.clamp(0.0, 1.0),
            ];
          }

          boxes.add({
            'label': label,
            'bbox': normBox,
            'confidence': item['confidence'] as double?,
          });
        }
      }
    }

    return {'boxes': boxes};
  }

  /// 处理 Dio 错误
  Exception _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException('请求超时，请检查网络连接或增加超时时间');
      case DioExceptionType.connectionError:
        return ApiException('连接失败，请确认 API 服务已启动 (${error.message})');
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode;
        final data = error.response?.data;
        return ApiException('API 返回错误 (HTTP $status): $data');
      default:
        return ApiException('网络错误：${error.message}');
    }
  }
}

/// API 相关异常
class ApiException implements Exception {
  final String message;

  ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}

/// 为 DetectionResult 添加 copyWith 扩展
extension DetectionResultExtension on DetectionResult {
  DetectionResult copyWith({
    List<BoundingBox>? boxes,
    double? originalWidth,
    double? originalHeight,
    Duration? processingTime,
    String? rawResponse,
  }) {
    return DetectionResult(
      boxes: boxes ?? this.boxes,
      originalWidth: originalWidth ?? this.originalWidth,
      originalHeight: originalHeight ?? this.originalHeight,
      processingTime: processingTime ?? this.processingTime,
      rawResponse: rawResponse ?? this.rawResponse,
    );
  }
}

# LocalVision Box - 项目上下文文档

## 项目概述

**LocalVision Box** 是一个基于 Flutter 的本地 VLM（Vision Language Model）目标检测应用。用户通过自然语言提示词（如"找出所有的红色汽车"），应用会调用本地 VLM 服务进行 AI 分析，并在图片上自动绘制边界框。

### 核心特性
- 🔍 **自然语言检测**: 支持中文/英文提示词进行目标检测
- 🔒 **隐私优先**: 所有处理在本地完成，不上传云端
- 📱 **跨平台**: Windows/macOS/Linux/Android/iOS
- 🎨 **流畅交互**: 图片缩放、拖拽，边界框完美跟随
- ⚙️ **API 驱动**: 兼容 LM Studio、Ollama、LocalAI 等本地 VLM 服务

## 技术栈

| 类别 | 技术 |
|------|------|
| **框架** | Flutter (Stable Channel) |
| **SDK** | Dart >=3.0.0 <4.0.0 |
| **状态管理** | flutter_riverpod ^2.4.9 |
| **网络请求** | dio ^5.4.0 |
| **图片处理** | image_picker ^1.0.7, image ^4.1.7 |
| **持久化** | shared_preferences ^2.2.2 |
| **权限** | permission_handler ^11.3.0 |

## 项目结构

```
lib/
├── main.dart                 # 应用入口，初始化 Riverpod 和主题
├── models/
│   ├── bounding_box.dart     # 边界框数据模型（归一化坐标）
│   └── detection_result.dart # 检测结果数据模型
├── services/
│   ├── api_service.dart      # API 服务（Dio 封装，JSON 解析，坐标转换）
│   └── image_service.dart    # 图片服务（选取/压缩）
├── providers/
│   ├── app_provider.dart     # 应用配置管理（API 端点、模型名称等）
│   └── detection_provider.dart # 检测状态管理
├── widgets/
│   ├── bounding_box_painter.dart # 边界框绘制器（CustomPainter）
│   └── image_canvas.dart     # 图片画布组件（InteractiveViewer）
├── screens/
│   └── home_screen.dart      # 主界面
├── dialogs/
│   └── settings_dialog.dart  # 设置对话框（API 配置）
└── utils/                    # 工具类
```

## 构建和运行

### 环境要求
- Flutter SDK >= 3.0.0
- 本地 VLM 服务（如 LM Studio、Ollama）

### 安装依赖
```bash
flutter pub get
```

### 运行应用
```bash
flutter run
```

### 构建发布版本
```bash
flutter build windows  # Windows
flutter build macos    # macOS
flutter build linux    # Linux
flutter build apk      # Android
flutter build ios      # iOS
```

### 运行测试
```bash
flutter test
```

### 代码分析
```bash
flutter analyze
```

## API 协议

### 请求格式（OpenAI 兼容）
```json
{
  "model": "llava-v1.6-34b",
  "messages": [
    {
      "role": "system",
      "content": "You are a precise object detection assistant..."
    },
    {
      "role": "user",
      "content": [
        {"type": "text", "text": "找出所有的红色汽车"},
        {"type": "image_url", "image_url": {"url": "data:image/jpeg;base64,..."}}
      ]
    }
  ],
  "temperature": 0.1
}
```

### 响应格式
```json
{
  "boxes": [
    {
      "label": "红色汽车",
      "bbox": [0.1, 0.2, 0.5, 0.8],
      "confidence": 0.95
    }
  ]
}
```

**坐标说明**:
- 归一化坐标 (0.0-1.0)，相对于原始图片尺寸
- 格式：[xmin, ymin, xmax, ymax]
- 原点 (0,0) 在左上角

### 支持的 VLM 服务

| 服务 | 默认端口 | 说明 |
|------|---------|------|
| LM Studio | 1234 | 推荐，支持多种 VLM 模型 |
| Ollama | 11434 | 开源，支持 llava 等模型 |
| LocalAI | 8080 | 兼容 OpenAI API |

## 开发规范

### 代码风格
遵循 `analysis_options.yaml` 配置：
- 使用 `const` 构造函数
- 使用单引号字符串
- Widget 子属性按字母排序
- 避免使用 `print()`
- Widget 构造函数添加 `key` 参数

### 架构模式
- **状态管理**: Riverpod Provider 模式
- **分层架构**: Models → Services → Providers → Widgets/Screens
- **坐标处理**: 统一使用归一化坐标 (0.0-1.0) 存储，显示时转换为屏幕坐标

### 关键设计决策

1. **归一化坐标**: `BoundingBox` 存储归一化坐标，支持任意尺寸的图片显示
2. **JSON 容错**: `ApiService._parseJsonResponse` 支持多种 JSON 格式和 Markdown 包裹
3. **坐标转换**: 支持像素坐标和归一化坐标的自动检测与转换
4. **超时设置**: API 请求默认 120 秒超时（VLM 推理较慢）

## 核心类说明

### BoundingBox (`lib/models/bounding_box.dart`)
- 存储归一化坐标和原始图片尺寸
- 提供 `toScreenRect()` 方法转换为屏幕坐标
- 提供 `containsPoint()` 方法用于点击检测

### DetectionResult (`lib/models/detection_result.dart`)
- 封装检测结果，包含边界框列表和图片信息
- 提供 `boxCount`、`hasResults`、`uniqueLabels` 等便捷属性

### ApiService (`lib/services/api_service.dart`)
- Dio 客户端封装，处理 API 通信
- Base64 图片编码
- JSON 响应清洗与解析（支持多种格式）
- 坐标转换（像素 ↔ 归一化）
- 错误处理与超时管理

## 常见问题

### 连接失败
- 确认 VLM 服务已启动
- 检查 Base URL 是否正确（包含 `/v1` 后缀）
- 确认防火墙未阻止连接

### JSON 解析失败
- 确保模型支持 JSON 输出格式
- 检查系统提示词是否被正确发送
- 尝试更换模型（推荐 llava-v1.6-34b）

### 边界框偏移
- 应用会自动处理坐标变换
- 如仍有问题，检查 `modelOutputWidth`/`modelOutputHeight` 参数（某些模型使用固定输出尺寸）

## 相关文档

- [README.md](README.md) - 用户文档和使用说明
- [pubspec.yaml](pubspec.yaml) - 依赖配置
- [analysis_options.yaml](analysis_options.yaml) - 代码规范配置

# LocalVision Box

本地 VLM 目标检测应用 - 通过自然语言提示词在图片上绘制边界框

## 功能特性

- 🔍 **自然语言检测**: 输入提示词 (如"找出所有的红色汽车")，自动识别并绘制边界框
- 🔒 **隐私优先**: 所有处理在本地完成，不上传云端
- 📱 **跨平台支持**: Windows/macOS/Linux/Android/iOS
- 🎨 **流畅交互**: 支持图片缩放、拖拽，边界框完美跟随
- ⚙️ **API 驱动**: 兼容 LM Studio、Ollama 等本地 VLM 服务

## 技术栈

- **框架**: Flutter (Stable Channel)
- **状态管理**: flutter_riverpod
- **网络请求**: dio
- **图片处理**: image_picker, image
- **交互组件**: InteractiveViewer + CustomPainter

## 快速开始

### 1. 环境要求

- Flutter SDK >= 3.0.0
- 本地 VLM 服务 (如 LM Studio、Ollama)

### 2. 安装依赖

```bash
flutter pub get
```

### 3. 配置 API 端点

1. 启动本地 VLM 服务 (如 LM Studio)
2. 在应用设置中配置:
   - **Base URL**: `http://localhost:1234/v1` (根据实际服务调整)
   - **Model Name**: `llava-v1.6-34b` (根据实际模型调整)
3. 点击"测试连接"验证配置

### 4. 运行应用

```bash
flutter run
```

## 使用说明

1. **选择图片**: 点击"选择图片"按钮，从相册或文件管理器中选择图片
2. **输入提示词**: 在底部输入框中输入检测目标 (如"找出所有的猫")
3. **开始检测**: 点击"开始检测"按钮，等待 AI 分析
4. **查看结果**: 
   - 边界框会绘制在图片上
   - 点击边界框查看详情
   - 双指缩放/拖拽查看图片细节

## API 协议

应用使用 OpenAI 兼容格式与本地 VLM 服务通信：

### 请求格式

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
  "temperature": 0.1,
  "response_format": {"type": "json_schema"}
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

## 项目结构

```
lib/
├── main.dart                 # 应用入口
├── models/
│   ├── bounding_box.dart     # 边界框数据模型
│   └── detection_result.dart # 检测结果数据模型
├── services/
│   ├── api_service.dart      # API 服务 (Dio 封装)
│   └── image_service.dart    # 图片服务 (选取/压缩)
├── providers/
│   ├── app_provider.dart     # 配置管理
│   └── detection_provider.dart # 检测状态管理
├── widgets/
│   ├── bounding_box_painter.dart # 边界框绘制器
│   └── image_canvas.dart     # 图片画布组件
├── screens/
│   └── home_screen.dart      # 主界面
└── dialogs/
    └── settings_dialog.dart  # 设置对话框
```

## 支持的 VLM 服务

| 服务 | 默认端口 | 说明 |
|------|---------|------|
| LM Studio | 1234 | 推荐，支持多种 VLM 模型 |
| Ollama | 11434 | 开源，支持 llava 等模型 |
| LocalAI | 8080 | 兼容 OpenAI API |

## 常见问题

### 连接失败
- 确认 VLM 服务已启动
- 检查 Base URL 是否正确 (包含 `/v1` 后缀)
- 确认防火墙未阻止连接

### JSON 解析失败
- 确保模型支持 JSON 输出格式
- 检查系统提示词是否被正确发送
- 尝试更换模型 (推荐 llava-v1.6-34b)

### 边界框偏移
- 应用会自动处理坐标变换
- 如仍有问题，请报告具体场景

## 开发计划

- [ ] 批量图片处理
- [ ] 导出检测结果 (JSON/COCO 格式)
- [ ] 历史记录功能
- [ ] 自定义边界框样式
- [ ] 多语言支持

## 许可证

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request！

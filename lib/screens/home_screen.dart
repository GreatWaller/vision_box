import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/detection_provider.dart';
import '../../providers/app_provider.dart';
import '../../widgets/image_canvas.dart';
import '../../dialogs/settings_dialog.dart';

/// 主界面 - LocalVision Box 主要操作界面
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late TextEditingController _promptController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController();
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  /// 选择图片
  Future<void> pickImage() async {
    final notifier = ref.read(detectionProvider.notifier);
    await notifier.pickAndLoadImage();
  }

  /// 执行检测
  Future<void> runDetection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      _showSnackBar('请输入提示词', isError: true);
      return;
    }

    final notifier = ref.read(detectionProvider.notifier);
    await notifier.detectObjects(prompt);
  }

  /// 重置所有状态
  void resetAll() {
    ref.read(detectionProvider.notifier).reset();
    _promptController.clear();
  }

  /// 显示设置对话框
  Future<void> showSettings() async {
    await showSettingsDialog(context);
  }

  /// 显示 SnackBar
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// 显示边界框详情
  void _showBoxDetails(int index) {
    final state = ref.read(detectionProvider);
    if (state.result == null || index >= state.result!.boxes.length) return;

    final box = state.result!.boxes[index];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('边界框详情 #${index + 1}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('标签', box.label),
            _buildDetailRow('置信度', box.confidence != null 
                ? '${(box.confidence! * 100).toStringAsFixed(1)}%' 
                : 'N/A'),
            const Divider(),
            _buildDetailRow('左上角 X', '${box.xMinNorm.toStringAsFixed(4)} (${box.xMinPixel.toStringAsFixed(0)}px)'),
            _buildDetailRow('左上角 Y', '${box.yMinNorm.toStringAsFixed(4)} (${box.yMinPixel.toStringAsFixed(0)}px)'),
            _buildDetailRow('右下角 X', '${box.xMaxNorm.toStringAsFixed(4)} (${box.xMaxPixel.toStringAsFixed(0)}px)'),
            _buildDetailRow('右下角 Y', '${box.yMaxNorm.toStringAsFixed(4)} (${box.yMaxPixel.toStringAsFixed(0)}px)'),
            const Divider(),
            _buildDetailRow('宽度', '${box.widthPixel.toStringAsFixed(0)}px'),
            _buildDetailRow('高度', '${box.heightPixel.toStringAsFixed(0)}px'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(detectionProvider);
    final config = ref.watch(appConfigProvider);

    return Scaffold(
      appBar: _buildAppBar(state),
      body: Column(
        children: [
          // 主画布区域
          Expanded(
            child: _buildCanvas(state),
          ),
          
          // 底部控制栏
          _buildControlBar(state, config),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(DetectionStateData state) {
    return AppBar(
      title: const Text('LocalVision Box'),
      actions: [
        // 检测结果计数
        if (state.hasResult)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Chip(
              avatar: const Icon(Icons.check_circle, size: 18),
              label: Text('${state.result!.boxCount} 个物体'),
              backgroundColor: state.result!.hasResults
                  ? Colors.green.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.2),
            ),
          ),
        
        // 设置按钮
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: showSettings,
          tooltip: '设置',
        ),
      ],
    );
  }

  Widget _buildCanvas(DetectionStateData state) {
    return Stack(
      children: [
        // 画布内容
        if (state.hasImage && state.imageBytes != null)
          ImageCanvas(
            imageBytes: state.imageBytes!,
            originalWidth: state.originalWidth!,
            originalHeight: state.originalHeight!,
            boxes: state.result?.boxes ?? [],
            onBoxTap: (box) {
              final index = state.result?.boxes.indexOf(box);
              if (index != null) {
                _showBoxDetails(index);
              }
            },
          )
        else
          EmptyCanvasPlaceholder(
            message: state.errorMessage ?? '请选择一张图片开始检测',
            onPickImage: state.isProcessing ? null : pickImage,
          ),
        
        // 加载遮罩
        LoadingOverlay(
          isVisible: state.isProcessing,
          message: state.progressText ?? '正在处理...',
        ),
        
        // 错误提示
        if (state.isError && !state.hasImage)
          Positioned.fill(
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
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          state.errorMessage ?? '发生错误',
                          style: const TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () {
                            ref.read(detectionProvider.notifier).clearError();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('重试'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildControlBar(DetectionStateData state, AppConfig config) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 提示词输入
          Form(
            key: _formKey,
            child: TextFormField(
              controller: _promptController,
              decoration: InputDecoration(
                labelText: '检测提示词',
                hintText: '例如：找出所有的红色汽车',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: state.isProcessing
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
              enabled: !state.isProcessing && state.hasImage,
              onFieldSubmitted: (_) => runDetection(),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入提示词';
                }
                return null;
              },
            ),
          ),
          
          const SizedBox(height: 12),
          
          // 操作按钮
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // 选择图片按钮
              ElevatedButton.icon(
                onPressed: state.isProcessing ? null : pickImage,
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('选择图片'),
              ),
              
              // 检测按钮
              FilledButton.icon(
                onPressed: (state.hasImage && !state.isProcessing) 
                    ? runDetection 
                    : null,
                icon: state.isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(state.isProcessing ? '检测中...' : '开始检测'),
              ),

              // 重置按钮
              if (state.hasImage || state.hasResult)
                OutlinedButton.icon(
                  onPressed: state.isProcessing ? null : resetAll,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重置'),
                ),

              // 显示检测结果列表
              if (state.hasResult && state.result!.hasResults)
                OutlinedButton.icon(
                  onPressed: () => _showResultsList(),
                  icon: const Icon(Icons.list),
                  label: Text('列表 (${state.result!.boxCount})'),
                ),
            ],
          ),
          
          // 状态信息
          if (state.progressText != null && !state.isProcessing)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                state.progressText!,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 显示检测结果列表
  void _showResultsList() {
    final state = ref.read(detectionProvider);
    if (state.result == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.list),
                  const SizedBox(width: 8),
                  Text(
                    '检测结果 (${state.result!.boxCount} 个)',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            // 结果列表
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: state.result!.boxes.length,
                itemBuilder: (context, index) {
                  final box = state.result!.boxes[index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text('${index + 1}'),
                    ),
                    title: Text(box.label),
                    subtitle: Text(
                      '位置：(${box.xMinNorm.toStringAsFixed(2)}, ${box.yMinNorm.toStringAsFixed(2)}) - '
                      '(${box.xMaxNorm.toStringAsFixed(2)}, ${box.yMaxNorm.toStringAsFixed(2)})',
                    ),
                    trailing: box.confidence != null
                        ? Chip(
                            label: Text(
                              '${(box.confidence! * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(fontSize: 12, color: Colors.white),
                            ),
                            backgroundColor: Colors.green,
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          )
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      // 这里可以添加高亮对应边界框的逻辑
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

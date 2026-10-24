part of 'log_center_panel.dart';

/// Opens a zoomable preview for one error screenshot.
Future<void> showLogCenterErrorImagePreview(
  BuildContext context, {
  required ScriptLogBrowserController controller,
  required ScriptErrorLogDetail detail,
  required String imageName,
}) {
  final images = detail.images;
  if (images.isEmpty) {
    return Future<void>.value();
  }
  var initialIndex = images.indexWhere((item) => item.name == imageName);
  if (initialIndex < 0) {
    initialIndex = 0;
  }
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (dialogContext) {
      return _LogCenterErrorImagePreviewDialog(
        controller: controller,
        detail: detail,
        initialIndex: initialIndex,
      );
    },
  );
}

/// Dialog body for the zoomable error screenshot viewer.
class _LogCenterErrorImagePreviewDialog extends StatefulWidget {
  /// Creates one screenshot preview dialog.
  const _LogCenterErrorImagePreviewDialog({
    required this.controller,
    required this.detail,
    required this.initialIndex,
  });

  /// Log browser controller.
  final ScriptLogBrowserController controller;

  /// Error detail owning the screenshots.
  final ScriptErrorLogDetail detail;

  /// Index of the screenshot shown first.
  final int initialIndex;

  @override
  State<_LogCenterErrorImagePreviewDialog> createState() {
    return _LogCenterErrorImagePreviewDialogState();
  }
}

class _LogCenterErrorImagePreviewDialogState
    extends State<_LogCenterErrorImagePreviewDialog> {
  late int _index = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    final images = widget.detail.images;
    final image = images[_index];
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 920,
        height: 660,
        child: Column(
          children: [
            _buildHeader(context, image, images.length),
            Expanded(child: _buildStage(image, images.length)),
          ],
        ),
      ),
    );
  }

  /// Builds the dialog header with per-image actions.
  Widget _buildHeader(
    BuildContext context,
    ScriptErrorImageInfo image,
    int total,
  ) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          if (total > 1) ...[
            Text('${_index + 1}/$total', style: textTheme.titleSmall),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              image.name,
              style: textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _buildDownloadButton(image),
          if (widget.controller.canOpenErrorImageFolder)
            IconButton(
              tooltip: I18n.homeLogOpenImageFolder.tr,
              onPressed: _openFolder,
              icon: const Icon(Icons.folder_open_rounded),
            ),
          IconButton(
            tooltip: I18n.close.tr,
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  /// Builds the per-image download action with loading feedback.
  Widget _buildDownloadButton(ScriptErrorImageInfo image) {
    return Obx(() {
      final loading = widget.controller.isErrorImageDownloading(image);
      return IconButton(
        tooltip: I18n.homeLogDownloadImage.tr,
        onPressed: loading
            ? null
            : () => widget.controller.downloadErrorImage(image),
        icon: loading
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.download_rounded),
      );
    });
  }

  /// Builds the zoomable image stage with side navigation.
  Widget _buildStage(ScriptErrorImageInfo image, int total) {
    final url = ApiClient().buildScriptErrorImageUrl(
      widget.detail.id,
      image.name,
    );
    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(
            color: Colors.black,
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 8,
              child: Center(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) {
                      return child;
                    }
                    return const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white70,
                        size: 40,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        if (total > 1) ...[
          _buildStepButton(Icons.chevron_left_rounded, -1, left: true),
          _buildStepButton(Icons.chevron_right_rounded, 1, left: false),
        ],
      ],
    );
  }

  /// Builds one previous/next overlay button.
  Widget _buildStepButton(IconData icon, int delta, {required bool left}) {
    final button = IconButton(
      onPressed: () => _step(delta),
      icon: Icon(icon, color: Colors.white),
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.45),
      ),
    );
    return Align(
      alignment: left ? Alignment.centerLeft : Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: button,
      ),
    );
  }

  /// Moves the preview to another screenshot, wrapping around.
  void _step(int delta) {
    final total = widget.detail.images.length;
    if (total <= 1) {
      return;
    }
    setState(() {
      _index = (_index + delta + total) % total;
    });
  }

  /// Reveals the screenshot folder for the previewed error.
  void _openFolder() {
    widget.controller.openErrorImageFolder();
  }
}

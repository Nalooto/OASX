part of 'log_center_panel.dart';

extension _LogCenterErrorDetailLogSectionX on LogCenterErrorDetailView {
  /// Builds the virtualized error log body with progressive state feedback.
  Widget _buildLogBody(BuildContext context) {
    final lines = controller.selectedErrorLogLines;
    final hasImages =
        controller.selectedErrorDetail.value?.images.isNotEmpty ?? false;
    if (lines.isEmpty && !hasImages) {
      return _buildLogPlaceholder();
    }
    final wrapLines = controller.wrapLines.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller.errorLogPreparing.value ||
            controller.errorLogAppending.value)
          const LinearProgressIndicator(minHeight: 2),
        Expanded(child: _buildScrollableLines(context, wrapLines)),
      ],
    );
  }

  /// Builds the empty, loading or failed log placeholder.
  Widget _buildLogPlaceholder() {
    if (controller.errorMessage.value.isNotEmpty) {
      return Center(child: Text(controller.errorMessage.value));
    }
    if (controller.errorLogPreparing.value) {
      return const Center(child: CircularProgressIndicator());
    }
    return const SizedBox.shrink();
  }

  /// Builds the vertical line list, optionally widened for long lines.
  Widget _buildScrollableLines(BuildContext context, bool wrapLines) {
    final vertical = Scrollbar(
      controller: detailScrollController,
      interactive: true,
      thumbVisibility: true,
      notificationPredicate: (notification) {
        return notification.metrics.axis == Axis.vertical;
      },
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: ClipRect(child: _buildLineList(context, wrapLines: wrapLines)),
      ),
    );
    if (wrapLines) {
      return vertical;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = _resolveContentWidth(
          context,
          constraints.maxWidth,
          controller.selectedErrorLogMaxWidthScore.value,
        );
        return Scrollbar(
          controller: detailHorizontalScrollController,
          interactive: true,
          thumbVisibility: width > constraints.maxWidth,
          notificationPredicate: (notification) {
            return notification.metrics.axis == Axis.horizontal;
          },
          child: SingleChildScrollView(
            controller: detailHorizontalScrollController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: width, child: vertical),
          ),
        );
      },
    );
  }

  /// Builds the virtualized screenshot strip and log line list.
  Widget _buildLineList(BuildContext context, {required bool wrapLines}) {
    final detail = controller.selectedErrorDetail.value;
    final hasImages = detail != null && detail.images.isNotEmpty;
    final imageOffset = hasImages ? 1 : 0;
    final lines = controller.selectedErrorLogLines;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => _openCopyDialog(context),
      child: ListView.builder(
        controller: detailScrollController,
        padding: const EdgeInsets.only(top: 6, right: 12),
        itemCount: lines.length + imageOffset,
        itemBuilder: (context, index) {
          if (hasImages && index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _buildImages(detail),
            );
          }
          return LogCenterLogText(
            line: lines[index - imageOffset],
            maxLines: wrapLines ? null : 1,
            overflow: wrapLines ? TextOverflow.clip : TextOverflow.visible,
            softWrap: wrapLines,
          );
        },
      ),
    );
  }

  /// Opens the dedicated copy dialog with the current error-detail log body.
  void _openCopyDialog(BuildContext context) {
    showLogCenterCopyDialog(
      context,
      text: controller.selectedErrorLogText,
      onCopy: controller.copyText,
    );
  }

  /// Resolves one best-effort monospace width for horizontal scrolling.
  double _resolveContentWidth(
    BuildContext context,
    double viewportWidth,
    int widthScore,
  ) {
    final fontSize = Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14;
    final estimatedWidth = widthScore * fontSize * 0.64 + 48;
    return estimatedWidth < viewportWidth ? viewportWidth : estimatedWidth;
  }
}

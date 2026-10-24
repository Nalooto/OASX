part of 'script_log_browser_controller.dart';

/// Error list refresh cadence while the list page is visible.
const Duration _errorListRefreshInterval = Duration(seconds: 5);

extension ScriptLogBrowserErrorsX on ScriptLogBrowserController {
  /// Loads one page of error logs for the current script.
  Future<void> loadErrorList({bool reset = false}) async {
    if (errorListLoading.value && !reset) {
      return;
    }
    if (!reset && !errorHasMore.value) {
      return;
    }
    final requestId = reset ? ++revision : revision;
    final cursor = reset ? null : errorNextCursor;
    _errorListRequestId = requestId;
    errorListLoading.value = true;
    errorMessage.value = '';
    if (reset) {
      errorNextCursor = null;
      errorHasMore.value = false;
    }
    try {
      final page = await ApiClient().getScriptErrorLogs(
        scriptName: scriptName,
        cursor: cursor,
      );
      if (!isErrorListLoadActive(requestId)) {
        return;
      }
      if (reset) {
        errorItems.assignAll(page.items);
      } else {
        errorItems.addAll(page.items);
      }
      errorNextCursor = page.nextCursor;
      errorHasMore.value = page.hasMore;
      if (selectedErrorId.value.isEmpty && page.items.isNotEmpty) {
        errorDetailVisible.value = false;
      }
    } catch (error) {
      if (isErrorListLoadActive(requestId)) {
        errorMessage.value = error.toString();
      }
    } finally {
      if (isErrorListLoadActive(requestId)) {
        errorListLoading.value = false;
      }
      if (_errorListRequestId == requestId) {
        _errorListRequestId = 0;
      }
    }
  }

  /// Starts background refresh for the visible error list page.
  void startErrorListAutoRefresh() {
    errorListRefreshTimer ??= Timer.periodic(
      _errorListRefreshInterval,
      (_) => unawaited(refreshVisibleErrorList()),
    );
  }

  /// Stops background error-list refresh.
  void stopErrorListAutoRefresh() {
    errorListRefreshTimer?.cancel();
    errorListRefreshTimer = null;
  }

  /// Refreshes the error list when it is the visible page.
  ///
  /// New errors are prepended in place so already loaded pages, the selected
  /// error and the viewport stay untouched. Manual browsing (scrolled away from
  /// the top edge) and detail pages are left alone.
  Future<void> refreshVisibleErrorList() async {
    if (activeTab.value != ScriptLogBrowserTab.error) {
      return;
    }
    if (errorDetailVisible.value) {
      return;
    }
    if (errorListLoading.value || _errorPeekRunning) {
      return;
    }
    if (!(isErrorListAtTop?.call() ?? true)) {
      return;
    }
    _errorPeekRunning = true;
    final revisionAtStart = revision;
    try {
      final page = await ApiClient().getScriptErrorLogs(
        scriptName: scriptName,
      );
      if (isClosed ||
          revisionAtStart != revision ||
          activeTab.value != ScriptLogBrowserTab.error ||
          errorDetailVisible.value) {
        return;
      }
      if (errorItems.isEmpty) {
        errorItems.assignAll(page.items);
        errorNextCursor = page.nextCursor;
        errorHasMore.value = page.hasMore;
        return;
      }
      final newCount = _countNewErrorItems(page.items);
      if (newCount == 0) {
        return;
      }
      if (newCount < 0) {
        unawaited(loadErrorList(reset: true));
        return;
      }
      errorItems.insertAll(0, page.items.take(newCount));
    } catch (_) {
      // Silent refresh: keep the current list when the peek request fails.
    } finally {
      _errorPeekRunning = false;
    }
  }

  /// Counts new items before the current first item.
  ///
  /// Returns `-1` when the incoming page and the cached list share no item.
  int _countNewErrorItems(List<ScriptErrorLogItem> incoming) {
    if (errorItems.isEmpty) {
      return incoming.length;
    }
    final firstId = errorItems.first.id;
    for (var index = 0; index < incoming.length; index++) {
      if (incoming[index].id == firstId) {
        return index;
      }
    }
    return -1;
  }

  /// Loads detail for one selected error id.
  Future<void> selectError(String errorId) async {
    final normalized = errorId.trim();
    if (normalized.isEmpty) {
      return;
    }
    ScriptErrorLogItem? selectedItem;
    for (final item in errorItems) {
      if (item.id == normalized) {
        selectedItem = item;
        break;
      }
    }
    final requestId = revision;
    final renderToken = ++_errorDetailRenderToken;
    _errorDetailRequestId = requestId;
    selectedErrorId.value = normalized;
    selectedErrorTitle.value = selectedItem == null
        ? ''
        : formatErrorTimestamp(selectedItem.timestampMs, selectedItem.time);
    resetSelectedErrorRenderState();
    selectedErrorDetail.value = null;
    errorDetailVisible.value = true;
    errorDetailLoading.value = true;
    errorMessage.value = '';
    resetErrorDetailViewport?.call();
    try {
      final detail = await ApiClient().getScriptErrorLogDetail(normalized);
      if (!isErrorDetailLoadActive(requestId) ||
          selectedErrorId.value != normalized) {
        return;
      }
      selectedErrorDetail.value = detail;
      scheduleSelectedErrorLogPreparation(
        detail: detail,
        renderToken: renderToken,
      );
    } catch (error) {
      if (isErrorDetailLoadActive(requestId)) {
        errorMessage.value = error.toString();
      }
    } finally {
      if (isErrorDetailLoadActive(requestId)) {
        errorDetailLoading.value = false;
      }
      if (_errorDetailRequestId == requestId) {
        _errorDetailRequestId = 0;
      }
    }
  }

  /// Copies the selected error log text.
  void copySelectedErrorLog() {
    final text = selectedErrorLogText.isEmpty
        ? selectedErrorDetail.value?.log.content ?? ''
        : selectedErrorLogText;
    copyText(text);
  }

  /// Returns to the error list page.
  void backToErrorList() {
    cancelSelectedErrorRenderWork();
    errorDetailVisible.value = false;
    unawaited(refreshVisibleErrorList());
  }

  /// Formats one error timestamp for list and detail headers.
  String formatErrorTimestamp(int timestamp, String fallback) {
    if (timestamp <= 0) {
      return fallback;
    }
    final time = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${time.year.toString().padLeft(4, '0')}-'
        '${time.month.toString().padLeft(2, '0')}-'
        '${time.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}.'
        '${time.millisecond.toString().padLeft(3, '0')}';
  }

  /// Returns whether one error image download is running.
  bool isErrorImageDownloading(ScriptErrorImageInfo image) {
    return downloadingImageKeys.contains(errorImageDownloadKey(image));
  }

  /// Builds a stable key for the selected error image.
  String errorImageDownloadKey(ScriptErrorImageInfo image) {
    final detailId = selectedErrorDetail.value?.id ?? selectedErrorId.value;
    return '$detailId/${image.name}';
  }

  /// Downloads one error image.
  Future<void> downloadErrorImage(ScriptErrorImageInfo image) async {
    final detail = selectedErrorDetail.value;
    if (detail == null) {
      return;
    }
    final downloadKey = '${detail.id}/${image.name}';
    if (downloadingImageKeys.contains(downloadKey)) {
      return;
    }
    downloadingImageKeys.add(downloadKey);
    try {
      final payload = await ApiClient().getScriptErrorImage(
        detail.id,
        image.name,
      );
      if (kIsWeb) {
        await downloadBytesToBrowser(
          payload.bytes,
          payload.fileName,
          mimeType: 'image/png',
        );
        Get.snackbar(
          I18n.tip.tr,
          I18n.homeLogImageSaveSuccess.tr,
          duration: const Duration(seconds: 1),
        );
        return;
      }
      final path = await FilePicker.platform.saveFile(
        fileName: payload.fileName,
        type: FileType.image,
        allowedExtensions: const ['png'],
        bytes: payload.bytes,
      );
      if (path == null || path.trim().isEmpty) {
        return;
      }
      if (!_isMobileTargetPlatform()) {
        await saveBytesToPath(path, payload.bytes);
      }
      Get.snackbar(
        I18n.tip.tr,
        I18n.homeLogImageSaveSuccess.tr,
        duration: const Duration(seconds: 1),
      );
    } catch (_) {
      Get.snackbar(
        I18n.tip.tr,
        I18n.homeLogImageSaveFailed.tr,
        duration: const Duration(seconds: 2),
      );
    } finally {
      downloadingImageKeys.remove(downloadKey);
    }
  }

  /// Whether the screenshot folder action is available on this platform.
  bool get canOpenErrorImageFolder {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS;
  }

  /// Reveals the screenshot folder of the selected error.
  ///
  /// Opens `<OAS root>/log/error/<error_id>` when the backend runs locally.
  /// Falls back to downloading every screenshot into an app cache folder so a
  /// remote or relocated backend can still be inspected in the file manager.
  Future<void> openErrorImageFolder() async {
    if (!canOpenErrorImageFolder) {
      return;
    }
    final detail = selectedErrorDetail.value;
    if (detail == null || openingErrorImageFolder.value) {
      return;
    }
    openingErrorImageFolder.value = true;
    try {
      final localPath = _resolveSelectedErrorLocalDirectory(detail.id);
      if (localPath != null && await localDirectoryExists(localPath)) {
        if (await revealLocalDirectory(localPath)) {
          _showErrorFolderSnackbar(I18n.homeLogOpenImageFolderReady.tr);
          return;
        }
      }
      final cachedPath = await _cacheSelectedErrorImages(detail);
      if (cachedPath != null && await revealLocalDirectory(cachedPath)) {
        _showErrorFolderSnackbar(I18n.homeLogOpenImageFolderReady.tr);
        return;
      }
      _showErrorFolderSnackbar(I18n.homeLogOpenImageFolderFailed.tr);
    } finally {
      openingErrorImageFolder.value = false;
    }
  }

  /// Resolves the local error directory when the backend is on this machine.
  String? _resolveSelectedErrorLocalDirectory(String errorId) {
    final storage = GetStorage();
    return resolveLocalErrorDirectory(
      rootPath: storage.read(StorageKey.rootPathServer.name)?.toString() ?? '',
      address: storage.read(StorageKey.address.name)?.toString() ?? '',
      errorId: errorId,
    );
  }

  /// Downloads all screenshots of one error into a cache folder.
  Future<String?> _cacheSelectedErrorImages(ScriptErrorLogDetail detail) async {
    if (detail.images.isEmpty) {
      _showErrorFolderSnackbar(I18n.homeLogOpenImageFolderFailed.tr);
      return null;
    }
    _showErrorFolderSnackbar(I18n.homeLogImagePreparing.tr);
    final names = <String>[];
    final payloads = <Uint8List>[];
    try {
      for (final image in detail.images) {
        final payload = await ApiClient().getScriptErrorImage(
          detail.id,
          image.name,
        );
        names.add(payload.fileName);
        payloads.add(payload.bytes);
      }
    } catch (_) {
      return null;
    }
    return writeErrorScreenshotFolder(
      errorId: detail.id,
      names: names,
      payloads: payloads,
    );
  }

  /// Shows one short screenshot-folder status message.
  void _showErrorFolderSnackbar(String message) {
    Get.snackbar(
      I18n.tip.tr,
      message,
      duration: const Duration(seconds: 2),
    );
  }

  /// Returns whether the current runtime target is mobile.
  bool _isMobileTargetPlatform() {
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }
}

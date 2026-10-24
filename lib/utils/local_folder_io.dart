import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Returns whether one absolute directory exists on this machine.
Future<bool> localDirectoryExists(String path) async {
  if (path.trim().isEmpty) {
    return false;
  }
  try {
    return await Directory(path).exists();
  } catch (_) {
    return false;
  }
}

/// Reveals one directory in the platform file manager.
Future<bool> revealLocalDirectory(String path) async {
  if (path.trim().isEmpty) {
    return false;
  }
  final directory = Directory(path);
  try {
    if (!await directory.exists()) {
      return false;
    }
    if (Platform.isWindows) {
      await Process.start(
        'explorer.exe',
        [directory.path],
        mode: ProcessStartMode.detached,
      );
      return true;
    }
    if (Platform.isMacOS) {
      await Process.start(
        'open',
        [directory.path],
        mode: ProcessStartMode.detached,
      );
      return true;
    }
    if (Platform.isLinux) {
      await Process.start(
        'xdg-open',
        [directory.path],
        mode: ProcessStartMode.detached,
      );
      return true;
    }
  } catch (_) {
    return false;
  }
  return false;
}

/// Writes downloaded screenshots into one cache folder and returns its path.
Future<String?> writeErrorScreenshotFolder({
  required String errorId,
  required List<String> names,
  required List<Uint8List> payloads,
}) async {
  if (names.isEmpty || names.length != payloads.length) {
    return null;
  }
  final separator = Platform.pathSeparator;
  try {
    final support = await getApplicationSupportDirectory();
    final safeId = _safeSegment(errorId);
    final directory = Directory(
      '${support.path}${separator}error_screenshots$separator$safeId',
    );
    await directory.create(recursive: true);
    for (var index = 0; index < names.length; index++) {
      final file = File(
        '${directory.path}$separator${_safeSegment(names[index])}',
      );
      await file.writeAsBytes(payloads[index], flush: true);
    }
    return directory.path;
  } catch (_) {
    return null;
  }
}

/// Cleans one path segment so it cannot escape the cache directory.
String _safeSegment(String value) {
  final cleaned = value
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_')
      .replaceAll('..', '_')
      .trim();
  return cleaned.isEmpty ? 'image' : cleaned;
}

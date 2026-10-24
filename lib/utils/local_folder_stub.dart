import 'dart:typed_data';

/// No-op existence check for platforms without a local file system.
Future<bool> localDirectoryExists(String path) async => false;

/// No-op reveal action for platforms without a file manager.
Future<bool> revealLocalDirectory(String path) async => false;

/// No-op screenshot cache writer for platforms without a local file system.
Future<String?> writeErrorScreenshotFolder({
  required String errorId,
  required List<String> names,
  required List<Uint8List> payloads,
}) async {
  return null;
}

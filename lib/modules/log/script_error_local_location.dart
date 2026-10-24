/// Resolves the local error log directory for one error id.
///
/// The OAS backend only returns the error directory name (`error_id`), while
/// screenshots live under `<OAS root>/log/error/<error_id>`. This helper rebuilds
/// that path when the backend runs on the local machine.
///
/// [rootPath] is the configured OAS root path, [address] the backend address
/// and [errorId] the id returned by `/logs/errors`.
///
/// Returns `null` when the path cannot be resolved safely.
String? resolveLocalErrorDirectory({
  required String rootPath,
  required String address,
  required String errorId,
}) {
  if (!isLocalBackendAddress(address)) {
    return null;
  }
  final root = rootPath.trim();
  final id = errorId.trim();
  if (root.isEmpty || id.isEmpty) {
    return null;
  }
  if (id.contains('/') || id.contains('\\') || id.contains('..')) {
    return null;
  }
  final separator = root.contains('\\') ? '\\' : '/';
  var normalizedRoot = root;
  while (normalizedRoot.endsWith('\\') || normalizedRoot.endsWith('/')) {
    normalizedRoot = normalizedRoot.substring(0, normalizedRoot.length - 1);
  }
  if (normalizedRoot.isEmpty) {
    return null;
  }
  return '$normalizedRoot${separator}log${separator}error$separator$id';
}

/// Returns whether one backend address points at the local machine.
bool isLocalBackendAddress(String address) {
  final raw = address.trim();
  if (raw.isEmpty) {
    return true;
  }
  final host = Uri.tryParse(raw)?.host ?? '';
  if (host.isEmpty) {
    return true;
  }
  return host == '127.0.0.1' ||
      host == 'localhost' ||
      host == '::1' ||
      host == '0.0.0.0';
}

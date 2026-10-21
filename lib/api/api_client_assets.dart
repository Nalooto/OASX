part of 'api_client.dart';

extension ApiClientAssetsX on ApiClient {
  /// Loads the latest DailyTrifles asset snapshot for [scriptName].
  Future<ScriptAssetStats> getScriptAssets(String scriptName) async {
    final path = '/stats/${Uri.encodeComponent(scriptName)}/assets';
    final res = await request(() => get(path));
    if (!res.isSuccess || res.data is! Map) {
      throw Exception(res.error ?? 'Invalid asset stats response');
    }
    return ScriptAssetStats.fromJson(Map<String, dynamic>.from(res.data));
  }

  /// Triggers a one-shot asset read on the backend and returns the new snapshot.
  ///
  /// The read itself takes ~10-15s. If the POST response is lost or the client
  /// aborts early, fall back to polling GET until `updated_at` changes.
  Future<ScriptAssetStats> refreshScriptAssets(String scriptName) async {
    final before = await getScriptAssets(scriptName);
    Object? failure;
    var fatal = false;
    try {
      final path = '/stats/${Uri.encodeComponent(scriptName)}/assets/refresh';
      final res = await request(() => post(path));
      if (res.isSuccess && res.data is Map) {
        return ScriptAssetStats.fromJson(Map<String, dynamic>.from(res.data));
      }
      final code = res.code;
      if (code == 404 || (code != null && code >= 500)) {
        fatal = true;
        failure = res.error ?? 'HTTP $code';
      } else if (code != 409) {
        // 409 means another refresh is already running: just wait for it.
        failure = res.error;
      }
    } catch (e) {
      failure = e;
    }
    if (fatal) {
      throw Exception(failure?.toString() ?? '刷新失败');
    }

    for (var i = 0; i < 60; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      try {
        final stats = await getScriptAssets(scriptName);
        final updated = stats.updatedAt;
        if (updated != null && updated != before.updatedAt) {
          return stats;
        }
      } catch (_) {
        // keep polling; backend may be busy
      }
    }
    throw Exception(failure?.toString() ?? '刷新超时（60s）');
  }
}

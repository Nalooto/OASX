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
  Future<ScriptAssetStats> refreshScriptAssets(String scriptName) async {
    final path = '/stats/${Uri.encodeComponent(scriptName)}/assets/refresh';
    final res = await request(() => post(path));
    if (!res.isSuccess || res.data is! Map) {
      throw Exception(res.error ?? 'Asset refresh failed');
    }
    return ScriptAssetStats.fromJson(Map<String, dynamic>.from(res.data));
  }
}

/// Models for the `/stats/{script}/assets` response written by DailyTrifles.
class ScriptAssetItem {  /// Creates one asset row.
  const ScriptAssetItem({
    required this.key,
    required this.label,
    required this.value,
    this.icon = '',
    this.prev,
  });

  /// Parses one asset row from server JSON.
  factory ScriptAssetItem.fromJson(Map<String, dynamic> json) {
    return ScriptAssetItem(
      key: (json['key'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      icon: (json['icon'] ?? '').toString(),
      value: _readInt(json['value']),
      prev: json['prev'] == null ? null : _readInt(json['prev']),
    );
  }

  /// Stable asset identifier, e.g. `gold`.
  final String key;

  /// Localized display name.
  final String label;

  /// Game icon resource name recorded by the backend.
  final String icon;

  /// Current amount.
  final int value;

  /// Previous amount, null when no earlier snapshot exists.
  final int? prev;

  /// Difference against the previous snapshot.
  int? get delta => prev == null ? null : value - prev!;
}

/// One daily asset snapshot used for date comparison.
class ScriptAssetDay {
  /// Creates a daily snapshot.
  const ScriptAssetDay({
    required this.date,
    required this.items,
    this.updatedAt,
  });

  /// Parses one day from server JSON.
  factory ScriptAssetDay.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final items = <String, int>{};
    if (raw is Map) {
      raw.forEach((key, value) {
        items[key.toString()] = _readInt(value);
      });
    }
    return ScriptAssetDay(
      date: (json['date'] ?? '').toString(),
      updatedAt: json['updated_at']?.toString(),
      items: items,
    );
  }

  /// Date key, `yyyy-MM-dd`.
  final String date;

  /// ISO timestamp of the last read that day.
  final String? updatedAt;

  /// Asset values for that day.
  final Map<String, int> items;
}

/// Latest asset snapshot for one script.
class ScriptAssetStats {
  /// Creates an asset snapshot.
  const ScriptAssetStats({
    required this.scriptName,
    required this.available,
    required this.items,
    this.updatedAt,
    this.source,
    this.account = const <String, dynamic>{},
    this.days = const <ScriptAssetDay>[],
  });

  /// Parses the snapshot payload.
  factory ScriptAssetStats.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map((item) => ScriptAssetItem.fromJson(Map<String, dynamic>.from(item)))
            .where((item) => item.key.isNotEmpty)
            .toList(growable: false)
        : const <ScriptAssetItem>[];
    final rawDays = json['days'];
    final days = rawDays is List
        ? rawDays
            .whereType<Map>()
            .map((day) => ScriptAssetDay.fromJson(Map<String, dynamic>.from(day)))
            .where((day) => day.date.isNotEmpty)
            .toList()
        : <ScriptAssetDay>[];
    days.sort((a, b) => a.date.compareTo(b.date));
    final rawAccount = json['account'];
    return ScriptAssetStats(
      scriptName: (json['script_name'] ?? '').toString(),
      available: json['available'] == true,
      updatedAt: json['updated_at']?.toString(),
      source: json['source']?.toString(),
      account: rawAccount is Map ? Map<String, dynamic>.from(rawAccount) : const {},
      items: items,
      days: days,
    );
  }

  /// Script/config name.
  final String scriptName;

  /// Whether the backend found a snapshot file.
  final bool available;

  /// ISO timestamp of the snapshot.
  final String? updatedAt;

  /// Snapshot producer, e.g. `mumu-frida`.
  final String? source;

  /// Account summary (nickname/level/avatar id).
  final Map<String, dynamic> account;

  /// Asset rows in display order.
  final List<ScriptAssetItem> items;

  /// Daily snapshots sorted ascending by date.
  final List<ScriptAssetDay> days;

  /// Whether there is anything worth rendering.
  bool get hasData => available && items.isNotEmpty;

  /// Account nickname when present.
  String get accountName => (account['name'] ?? '').toString();
}

int _readInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

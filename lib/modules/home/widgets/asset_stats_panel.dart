import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oasx/api/api_client.dart';
import 'package:oasx/modules/home/models/asset_stats_models.dart';
import 'package:oasx/modules/home/widgets/asset_stats_formatters.dart';
import 'package:oasx/modules/home/widgets/asset_trend_sheet.dart';
import 'package:oasx/translation/i18n_content.dart';

/// Quick ranges offered by the asset panel's comparison bar.
enum _AssetRangePreset { previousDay, lastWeek, lastMonth, allHistory }

/// Right-sidebar tab that renders the asset snapshot history.
///
/// Two dates can be selected, and every tile then shows how that asset moved
/// between them, so changes over a span of days become visible at a glance.
class AssetStatsPanel extends StatefulWidget {
  /// Creates the asset panel for one script.
  const AssetStatsPanel({
    super.key,
    required this.scriptName,
    this.statsLoader,
  });

  /// Active script/config name.
  final String scriptName;

  /// Optional stats source, defaults to the backend API. Used by tests.
  final Future<ScriptAssetStats> Function(String scriptName)? statsLoader;

  @override
  State<AssetStatsPanel> createState() => _AssetStatsPanelState();
}

class _AssetStatsPanelState extends State<AssetStatsPanel> {
  ScriptAssetStats? _stats;
  bool _loading = false;
  bool _refreshing = false;
  String? _error;
  String? _startDate;
  String? _endDate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AssetStatsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scriptName != widget.scriptName) {
      _stats = null;
      _startDate = null;
      _endDate = null;
      _load();
    }
  }

  void _applyStats(ScriptAssetStats stats) {
    _stats = stats;
    final days = stats.days;
    if (days.isEmpty) {
      _startDate = null;
      _endDate = null;
      return;
    }
    // Keep the user's range across refreshes, unless it no longer exists.
    final keepEnd = stats.dayOf(_endDate) != null;
    final keepStart = stats.dayOf(_startDate) != null;
    final end = keepEnd ? _endDate! : days.last.date;
    var start = keepStart ? _startDate! : (days.length > 1
        ? days[days.length - 2].date
        : days.last.date);
    if (start.compareTo(end) > 0) {
      start = end;
    }
    _startDate = start;
    _endDate = end;
  }

  Future<void> _load() async {
    if (widget.scriptName.trim().isEmpty) {
      setState(() {
        _stats = null;
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final loader = widget.statsLoader;
      final name = widget.scriptName.trim();
      final stats = loader != null
          ? await loader(name)
          : await ApiClient().getScriptAssets(name);
      if (!mounted) {
        return;
      }
      setState(() {
        _applyStats(stats);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  /// Triggers a real re-read on the backend, not just a refreshed file read.
  Future<void> _refresh() async {
    if (_refreshing || widget.scriptName.trim().isEmpty) {
      return;
    }
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      final stats =
          await ApiClient().refreshScriptAssets(widget.scriptName.trim());
      if (!mounted) {
        return;
      }
      setState(() {
        _applyStats(stats);
        _refreshing = false;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _refreshing = false;
      });
      Get.snackbar(
        I18n.homeAssetsRefreshFailed.tr,
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// Updates the baseline date, keeping the range ordered.
  void _setStartDate(String value) {
    setState(() {
      _startDate = value;
      if (_endDate == null || value.compareTo(_endDate!) > 0) {
        _endDate = value;
      }
    });
  }

  /// Updates the end date, keeping the range ordered.
  void _setEndDate(String value) {
    setState(() {
      _endDate = value;
      if (_startDate == null || _startDate!.compareTo(value) > 0) {
        _startDate = value;
      }
    });
  }

  /// Applies one of the quick ranges relative to the selected end date.
  void _applyPreset(_AssetRangePreset preset) {
    final stats = _stats;
    if (stats == null || stats.days.isEmpty) {
      return;
    }
    final days = stats.days;
    final endDay = stats.dayOf(_endDate) ?? days.last;
    final endIndex = days.indexOf(endDay);
    String back(int offset) {
      final index = endIndex - offset;
      return days[index < 0 ? 0 : index].date;
    }

    setState(() {
      _endDate = endDay.date;
      _startDate = switch (preset) {
        _AssetRangePreset.previousDay => back(1),
        _AssetRangePreset.lastWeek => back(6),
        _AssetRangePreset.lastMonth => back(29),
        _AssetRangePreset.allHistory => days.first.date,
      };
    });
  }

  void _openTrend(ScriptAssetItem item, ScriptAssetComparison comparison) {
    final stats = _stats;
    if (stats == null) {
      return;
    }
    showAssetTrendSheet(
      context,
      stats: stats,
      item: item,
      startDate: comparison.start?.date,
      endDate: comparison.end?.date,
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    if (_loading && stats == null) {
      return const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      );
    }
    if (_error != null && stats == null) {
      return _CenteredHint(
        icon: Icons.cloud_off_rounded,
        message: I18n.homeAssetsLoadFailed.tr,
        action: _load,
      );
    }
    if (stats == null || !stats.hasData) {
      return _CenteredHint(
        icon: Icons.inventory_2_outlined,
        message: I18n.homeAssetsEmpty.tr,
        action: _refresh,
      );
    }

    final days = stats.days;
    final comparison = stats.compare(_startDate, _endDate);
    final dates = days.map((day) => day.date).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(
          stats: stats,
          refreshing: _refreshing,
          onRefresh: _refresh,
        ),
        const SizedBox(height: 8),
        if (dates.isNotEmpty)
          _CompareBar(
            dates: dates,
            startDate: comparison.start?.date,
            endDate: comparison.end?.date,
            onStartChanged: _setStartDate,
            onEndChanged: _setEndDate,
            onPreset: _applyPreset,
          ),
        const SizedBox(height: 6),
        _InfoLine(
          summary: _compareSummary(stats, comparison),
          updatedLabel: _updatedLabel(
            comparison.end?.updatedAt ?? stats.updatedAt,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              mainAxisExtent: 74,
            ),
            itemCount: stats.items.length,
            itemBuilder: (context, index) {
              final item = stats.items[index];
              return _AssetTile(
                item: item,
                comparison: comparison,
                onTap: () => _openTrend(item, comparison),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Builds the `较 10-16 · 7 天 · 5 涨 / 1 跌` line, or the hint when the
  /// history is too short to compare.
  String _compareSummary(
    ScriptAssetStats stats,
    ScriptAssetComparison comparison,
  ) {
    if (!comparison.canCompare) {
      return I18n.homeAssetsCompareNeedMore.tr;
    }
    var up = 0;
    var down = 0;
    for (final item in stats.items) {
      final delta = comparison.delta(item.key);
      if (delta == null || delta == 0) {
        continue;
      }
      if (delta > 0) {
        up++;
      } else {
        down++;
      }
    }
    return I18n.homeAssetsCompareSummary.trParams({
      'date': formatAssetDayLabel(comparison.start?.date),
      'days': '${comparison.spanDays}',
      'up': '$up',
      'down': '$down',
    });
  }

  String _updatedLabel(String? iso) {
    if (iso == null || iso.isEmpty) {
      return '';
    }
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) {
      return '';
    }
    final local = parsed.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${I18n.homeAssetsUpdatedAt.tr} '
        '${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.stats,
    required this.refreshing,
    required this.onRefresh,
  });

  final ScriptAssetStats stats;
  final bool refreshing;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            stats.accountName.isEmpty
                ? I18n.homeAssetsTab.tr
                : '${I18n.homeAssetsTab.tr} · ${stats.accountName}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(
          width: 30,
          height: 30,
          child: refreshing
              ? const Padding(
                  padding: EdgeInsets.all(7),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  tooltip: I18n.homeAssetsRefresh.tr,
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                ),
        ),
      ],
    );
  }
}

/// Start/end date pickers plus the quick-range menu.
class _CompareBar extends StatelessWidget {
  const _CompareBar({
    required this.dates,
    required this.startDate,
    required this.endDate,
    required this.onStartChanged,
    required this.onEndChanged,
    required this.onPreset,
  });

  final List<String> dates;
  final String? startDate;
  final String? endDate;
  final ValueChanged<String> onStartChanged;
  final ValueChanged<String> onEndChanged;
  final ValueChanged<_AssetRangePreset> onPreset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: _DateChip(
            label: I18n.homeAssetsCompareStart.tr,
            value: startDate,
            dates: dates,
            onChanged: onStartChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(
            Icons.arrow_right_alt_rounded,
            size: 18,
            color: theme.colorScheme.outline,
          ),
        ),
        Expanded(
          child: _DateChip(
            label: I18n.homeAssetsCompareEnd.tr,
            value: endDate,
            dates: dates,
            onChanged: onEndChanged,
          ),
        ),
        PopupMenuButton<_AssetRangePreset>(
          tooltip: I18n.homeAssetsComparePreset.tr,
          position: PopupMenuPosition.under,
          icon: Icon(
            Icons.date_range_rounded,
            size: 18,
            color: theme.colorScheme.outline,
          ),
          onSelected: onPreset,
          itemBuilder: (context) => _AssetRangePreset.values
              .map(
                (preset) => PopupMenuItem<_AssetRangePreset>(
                  value: preset,
                  height: 40,
                  child: Text(_presetLabel(preset)),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }

  String _presetLabel(_AssetRangePreset preset) {
    return switch (preset) {
      _AssetRangePreset.previousDay => I18n.homeAssetsPresetPrevDay.tr,
      _AssetRangePreset.lastWeek => I18n.homeAssetsPresetLastWeek.tr,
      _AssetRangePreset.lastMonth => I18n.homeAssetsPresetLastMonth.tr,
      _AssetRangePreset.allHistory => I18n.homeAssetsPresetAll.tr,
    };
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.label,
    required this.value,
    required this.dates,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> dates;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<String>(
      tooltip: label,
      initialValue: value,
      position: PopupMenuPosition.under,
      constraints: const BoxConstraints(maxHeight: 288, minWidth: 118),
      onSelected: onChanged,
      itemBuilder: (context) => dates.reversed
          .map(
            (date) => PopupMenuItem<String>(
              value: date,
              height: 38,
              child: Row(
                children: [
                  Expanded(child: Text(date)),
                  if (date == value)
                    Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                ],
              ),
            ),
          )
          .toList(growable: false),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 5, 4, 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.9),
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                formatAssetDayLabel(value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 16,
              color: theme.colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.summary, required this.updatedLabel});

  final String summary;
  final String updatedLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.outline,
    );
    return Tooltip(
      message: updatedLabel.isEmpty ? summary : '$summary\n$updatedLabel',
      child: Row(
        children: [
          Flexible(
            child: Text(
              summary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          if (updatedLabel.isNotEmpty) ...[
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                updatedLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: style,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AssetTile extends StatelessWidget {
  const _AssetTile({
    required this.item,
    required this.comparison,
    required this.onTap,
  });

  final ScriptAssetItem item;
  final ScriptAssetComparison comparison;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = assetColorFor(item.key);
    final value = comparison.endValue(item.key) ?? item.value;
    // Without a usable date range, fall back to the backend's own previous
    // value so the tile still shows a change.
    final startValue = comparison.canCompare
        ? comparison.startValue(item.key)
        : item.prev;
    final delta = startValue == null ? null : value - startValue;
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Tooltip(
          message: _tooltip(startValue, value, delta),
          waitDuration: const Duration(milliseconds: 500),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 38,
                  height: 38,
                  child: Image.asset(
                    'assets/images/asset_icons/${item.key}.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        assetIconFor(item.key),
                        size: 19,
                        color: color,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              formatAssetValue(value),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (delta != null && delta != 0) ...[
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                formatAssetDelta(delta),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: delta > 0
                                      ? assetGainColor
                                      : assetLossColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Tooltip that spells out the two endpoints behind the delta.
  String _tooltip(int? startValue, int value, int? delta) {
    if (startValue == null || delta == null) {
      return item.label;
    }
    final ratio = startValue <= 0 ? null : delta / startValue;
    final percent = ratio == null
        ? ''
        : ' (${ratio > 0 ? '+' : ''}${(ratio * 100).toStringAsFixed(1)}%)';
    return '${item.label}\n'
        '${formatAssetDayLabel(comparison.start?.date)} '
        '${formatAssetValue(startValue)} → '
        '${formatAssetDayLabel(comparison.end?.date)} '
        '${formatAssetValue(value)}\n'
        '${I18n.homeAssetsTrendChange.tr} '
        '${formatAssetDelta(delta)}$percent';
  }
}

class _CenteredHint extends StatelessWidget {
  const _CenteredHint({
    required this.icon,
    required this.message,
    required this.action,
  });

  final IconData icon;
  final String message;
  final Future<void> Function() action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 30, color: theme.colorScheme.outline),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: action,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(I18n.homeAssetsRefresh.tr),
            ),
          ],
        ),
      ),
    );
  }
}

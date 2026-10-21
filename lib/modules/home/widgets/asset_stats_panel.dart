import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oasx/api/api_client.dart';
import 'package:oasx/modules/home/models/asset_stats_models.dart';
import 'package:oasx/translation/i18n_content.dart';

/// Right-sidebar tab that renders the latest account asset snapshot.
class AssetStatsPanel extends StatefulWidget {
  /// Creates the asset panel for one script.
  const AssetStatsPanel({super.key, required this.scriptName});

  /// Active script/config name.
  final String scriptName;

  @override
  State<AssetStatsPanel> createState() => _AssetStatsPanelState();
}

class _AssetStatsPanelState extends State<AssetStatsPanel> {
  ScriptAssetStats? _stats;
  bool _loading = false;
  bool _refreshing = false;
  String? _error;
  String? _selectedDate;

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
      _selectedDate = null;
      _load();
    }
  }

  void _applyStats(ScriptAssetStats stats) {
    _stats = stats;
    _selectedDate =
        stats.days.isNotEmpty ? stats.days.last.date : _selectedDate;
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
      final stats = await ApiClient().getScriptAssets(widget.scriptName.trim());
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
    var selectedIndex = days.length - 1;
    if (days.isNotEmpty && _selectedDate != null) {
      final index = days.indexWhere((day) => day.date == _selectedDate);
      if (index >= 0) {
        selectedIndex = index;
      }
    }
    final selectedDay = days.isEmpty ? null : days[selectedIndex];
    final previousDay = selectedIndex > 0 ? days[selectedIndex - 1] : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(
          stats: stats,
          refreshing: _refreshing,
          selectedDate: selectedDay?.date,
          dates: days.map((day) => day.date).toList(growable: false),
          onRefresh: _refresh,
          onDateChanged: (value) => setState(() => _selectedDate = value),
        ),
        const SizedBox(height: 4),
        Text(
          _updatedLabel(selectedDay?.updatedAt ?? stats.updatedAt),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
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
              final value = selectedDay?.items[item.key] ?? item.value;
              final prev = selectedDay == null
                  ? item.prev
                  : previousDay?.items[item.key];
              return _AssetTile(item: item, value: value, prev: prev);
            },
          ),
        ),
      ],
    );
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
    required this.selectedDate,
    required this.dates,
    required this.onRefresh,
    required this.onDateChanged,
  });

  final ScriptAssetStats stats;
  final bool refreshing;
  final String? selectedDate;
  final List<String> dates;
  final Future<void> Function() onRefresh;
  final ValueChanged<String?> onDateChanged;

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
        if (dates.isNotEmpty)
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedDate,
              isDense: true,
              borderRadius: BorderRadius.circular(10),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              items: dates.reversed
                  .map(
                    (date) => DropdownMenuItem<String>(
                      value: date,
                      child: Text(date.substring(5)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: onDateChanged,
            ),
          ),
        const SizedBox(width: 2),
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

class _AssetTile extends StatelessWidget {
  const _AssetTile({required this.item, required this.value, this.prev});

  final ScriptAssetItem item;
  final int value;
  final int? prev;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _colorFor(item.key);
    final delta = prev == null ? null : value - prev!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
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
                child: Icon(_iconFor(item.key), size: 19, color: color),
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
                          '${delta > 0 ? '+' : ''}${formatAssetValue(delta)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: delta > 0
                                ? const Color(0xFF2E9E5B)
                                : const Color(0xFFD2544A),
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
    );
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

/// Formats an amount using 万/亿 units, matching the in-game asset panel.
String formatAssetValue(int value) {
  final number = value.abs();
  final sign = value < 0 ? '-' : '';
  if (number >= 100000000) {
    return '$sign${(number / 100000000).toStringAsFixed(2)}亿';
  }
  if (number >= 10000) {
    return '$sign${(number / 10000).toStringAsFixed(1)}万';
  }
  return '$sign$number';
}

IconData _iconFor(String key) {
  return switch (key) {
    'gold' => Icons.monetization_on_rounded,
    'ap' => Icons.bolt_rounded,
    'jade' => Icons.bubble_chart_rounded,
    'mystery_amulet' => Icons.style_rounded,
    'black_daruma' => Icons.smart_toy_rounded,
    'black_daruma_shard' => Icons.extension_rounded,
    'real_amulet' => Icons.local_activity_rounded,
    'soul_jade' => Icons.diamond_rounded,
    'oro_scale' => Icons.shield_rounded,
    'demon_soul' => Icons.local_fire_department_rounded,
    'yuling_key' => Icons.vpn_key_rounded,
    'hyakki_ticket' => Icons.confirmation_number_rounded,
    'honor' => Icons.military_tech_rounded,
    'medal' => Icons.workspace_premium_rounded,
    'contrib' => Icons.groups_rounded,
    'scroll_shard_large' => Icons.auto_stories_rounded,
    'scroll_shard_medium' => Icons.auto_stories_rounded,
    'scroll_shard_small' => Icons.auto_stories_rounded,
    _ => Icons.savings_rounded,
  };
}

Color _colorFor(String key) {
  return switch (key) {
    'gold' => const Color(0xFFE0A426),
    'ap' => const Color(0xFFEE7D3B),
    'jade' => const Color(0xFFE0533F),
    'mystery_amulet' => const Color(0xFF6E7BE8),
    'black_daruma' => const Color(0xFF5B5B66),
    'black_daruma_shard' => const Color(0xFF7A6F65),
    'real_amulet' => const Color(0xFF4E9BD8),
    'soul_jade' => const Color(0xFF3FA7A0),
    'oro_scale' => const Color(0xFF8C6BB1),
    'demon_soul' => const Color(0xFFC25B4E),
    'yuling_key' => const Color(0xFFB08A3E),
    'hyakki_ticket' => const Color(0xFF4C8F77),
    'honor' => const Color(0xFFB45F8A),
    'medal' => const Color(0xFF6C8FB8),
    'contrib' => const Color(0xFF7D9A4E),
    'scroll_shard_large' => const Color(0xFF9C6B4F),
    'scroll_shard_medium' => const Color(0xFF9C6B4F),
    'scroll_shard_small' => const Color(0xFF9C6B4F),
    _ => const Color(0xFF7A7A85),
  };
}

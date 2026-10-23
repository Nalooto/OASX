import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oasx/modules/home/models/asset_stats_models.dart';
import 'package:oasx/modules/home/widgets/asset_stats_formatters.dart';
import 'package:oasx/translation/i18n_content.dart';

const _kAssetTrendChartHeight = 132.0;
const _kAssetTrendAxisLabelWidth = 54.0;

/// Opens the history sheet of one asset, charting every stored snapshot and
/// highlighting the span selected in the asset panel.
Future<void> showAssetTrendSheet(
  BuildContext context, {
  required ScriptAssetStats stats,
  required ScriptAssetItem item,
  String? startDate,
  String? endDate,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => AssetTrendSheet(
      stats: stats,
      item: item,
      startDate: startDate,
      endDate: endDate,
    ),
  );
}

/// Per-asset history chart with the change over the selected range.
class AssetTrendSheet extends StatelessWidget {
  /// Creates the asset history sheet.
  const AssetTrendSheet({
    super.key,
    required this.stats,
    required this.item,
    this.startDate,
    this.endDate,
  });

  /// Full asset payload that owns the stored snapshots.
  final ScriptAssetStats stats;

  /// Asset row being inspected.
  final ScriptAssetItem item;

  /// Baseline date chosen in the panel.
  final String? startDate;

  /// End date chosen in the panel.
  final String? endDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final comparison = stats.compare(startDate, endDate);
    final color = assetColorFor(item.key);
    final series = _buildSeries(comparison);
    final currentValue = comparison.endValue(item.key) ?? item.value;
    final delta = comparison.delta(item.key);
    final ratio = comparison.ratio(item.key);
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SheetHeader(item: item, color: color),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      formatAssetValue(currentValue),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (delta != null && delta != 0) ...[
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _DeltaBadge(delta: delta, ratio: ratio),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _rangeLabel(comparison),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 16),
              if (series.values.length < 2)
                _ChartPlaceholder(message: I18n.homeAssetsTrendEmpty.tr)
              else
                _AssetTrendChart(
                  values: series.values,
                  dates: series.dates,
                  spanStart: series.spanStart,
                  spanEnd: series.spanEnd,
                  color: color,
                ),
              const SizedBox(height: 16),
              Divider(
                height: 1,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              _TrendStatRow(
                label: I18n.homeAssetsTrendStart.tr,
                value: comparison.startValue(item.key) == null
                    ? '--'
                    : formatAssetValue(comparison.startValue(item.key)!),
                trailing: formatAssetDayLabel(comparison.start?.date),
              ),
              _TrendStatRow(
                label: I18n.homeAssetsTrendEnd.tr,
                value: comparison.endValue(item.key) == null
                    ? '--'
                    : formatAssetValue(comparison.endValue(item.key)!),
                trailing: formatAssetDayLabel(comparison.end?.date),
              ),
              _TrendStatRow(
                label: I18n.homeAssetsTrendChange.tr,
                value: delta == null ? '--' : formatAssetDelta(delta),
                valueColor: _deltaColor(delta),
                trailing: ratio == null
                    ? null
                    : '${ratio > 0 ? '+' : ''}'
                        '${(ratio * 100).toStringAsFixed(1)}%',
              ),
              _TrendStatRow(
                label: I18n.homeAssetsTrendDaily.tr,
                value: delta == null || comparison.spanDays <= 0
                    ? '--'
                    : formatAssetDailyDelta(
                        delta / comparison.spanDays,
                        perDaySuffix: I18n.homeAssetsTrendPerDay.tr,
                      ),
                valueColor: _deltaColor(delta),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the plotted series and the highlighted span indexes.
  _AssetSeries _buildSeries(ScriptAssetComparison comparison) {
    final raw = stats.seriesFor(item.key);
    final firstKnown = raw.indexWhere((value) => value != null);
    if (firstKnown < 0) {
      return const _AssetSeries(values: [], dates: []);
    }
    final values = <int>[];
    final dates = <String>[];
    for (var i = firstKnown; i < raw.length; i++) {
      final value = raw[i];
      if (value == null) {
        continue;
      }
      values.add(value);
      dates.add(stats.days[i].date);
    }
    final startIndex = _indexOfDate(dates, comparison.start?.date);
    final endIndex = _indexOfDate(dates, comparison.end?.date);
    return _AssetSeries(
      values: values,
      dates: dates,
      spanStart: startIndex ?? 0,
      spanEnd: endIndex ?? values.length - 1,
    );
  }

  int? _indexOfDate(List<String> dates, String? date) {
    if (date == null) {
      return null;
    }
    final index = dates.indexOf(date);
    return index < 0 ? null : index;
  }

  /// Builds the `MM-dd → MM-dd · N 天` caption under the value.
  String _rangeLabel(ScriptAssetComparison comparison) {
    if (!comparison.canCompare) {
      return I18n.homeAssetsCompareNeedMore.tr;
    }
    return I18n.homeAssetsTrendSpan.trParams({
      'start': formatAssetDayLabel(comparison.start?.date),
      'end': formatAssetDayLabel(comparison.end?.date),
      'days': '${comparison.spanDays}',
    });
  }

  Color? _deltaColor(int? delta) {
    if (delta == null || delta == 0) {
      return null;
    }
    return delta > 0 ? assetGainColor : assetLossColor;
  }
}

class _AssetSeries {
  const _AssetSeries({
    required this.values,
    required this.dates,
    this.spanStart = 0,
    this.spanEnd = 0,
  });

  final List<int> values;
  final List<String> dates;
  final int spanStart;
  final int spanEnd;
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.item, required this.color});

  final ScriptAssetItem item;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
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
              child: Icon(assetIconFor(item.key), size: 19, color: color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                I18n.homeAssetsTrendTitle.tr,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: I18n.cancel.tr,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.close_rounded, size: 18),
        ),
      ],
    );
  }
}

class _DeltaBadge extends StatelessWidget {
  const _DeltaBadge({required this.delta, this.ratio});

  final int delta;
  final double? ratio;

  @override
  Widget build(BuildContext context) {
    final color = delta > 0 ? assetGainColor : assetLossColor;
    final ratio = this.ratio;
    final label = ratio == null
        ? formatAssetDelta(delta)
        : '${formatAssetDelta(delta)} (${ratio > 0 ? '+' : ''}'
            '${(ratio * 100).toStringAsFixed(1)}%)';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _TrendStatRow extends StatelessWidget {
  const _TrendStatRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.trailing,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
          if (trailing != null && trailing!.isNotEmpty) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 62,
              child: Text(
                trailing!,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChartPlaceholder extends StatelessWidget {
  const _ChartPlaceholder({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: _kAssetTrendChartHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
    );
  }
}

class _AssetTrendChart extends StatelessWidget {
  const _AssetTrendChart({
    required this.values,
    required this.dates,
    required this.spanStart,
    required this.spanEnd,
    required this.color,
  });

  final List<int> values;
  final List<String> dates;
  final int spanStart;
  final int spanEnd;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.outline,
    );
    final maxValue = values.reduce(math.max);
    final minValue = values.reduce(math.min);
    final span = (maxValue - minValue).abs();
    final padding =
        span == 0 ? math.max(maxValue.abs() * 0.1, 1.0) : span * 0.15;
    final top = maxValue + padding;
    final bottom = minValue - padding;
    final mid = (maxValue + minValue) / 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: _kAssetTrendChartHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: _kAssetTrendAxisLabelWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(formatAssetValue(maxValue.round()),
                        style: labelStyle, maxLines: 1),
                    Text(formatAssetValue(mid.round()),
                        style: labelStyle, maxLines: 1),
                    Text(formatAssetValue(minValue.round()),
                        style: labelStyle, maxLines: 1),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CustomPaint(
                  painter: _AssetTrendPainter(
                    values: values,
                    top: top,
                    bottom: bottom,
                    spanStart: spanStart,
                    spanEnd: spanEnd,
                    color: color,
                    gridColor: theme.colorScheme.outlineVariant
                        .withValues(alpha: 0.55),
                    surfaceColor: theme.colorScheme.surface,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const SizedBox(width: _kAssetTrendAxisLabelWidth + 8),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(formatAssetDayLabel(dates.first), style: labelStyle),
                  Text(formatAssetDayLabel(dates.last), style: labelStyle),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AssetTrendPainter extends CustomPainter {
  _AssetTrendPainter({
    required this.values,
    required this.top,
    required this.bottom,
    required this.spanStart,
    required this.spanEnd,
    required this.color,
    required this.gridColor,
    required this.surfaceColor,
  });

  final List<int> values;
  final double top;
  final double bottom;
  final int spanStart;
  final int spanEnd;
  final Color color;
  final Color gridColor;
  final Color surfaceColor;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final ratio in const [0.0, 0.5, 1.0]) {
      final y = size.height * ratio;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    if (values.length < 2) {
      return;
    }
    final double range = (top - bottom).abs() < 0.0001 ? 1 : top - bottom;
    double xAt(int index) => size.width * index / (values.length - 1);
    double yAt(int value) {
      final ratio = ((value - bottom) / range).clamp(0.0, 1.0).toDouble();
      return size.height * (1 - ratio);
    }

    final start = _clampIndex(spanStart, values.length - 1);
    final end = _clampIndex(spanEnd, values.length - 1);
    if (end > start) {
      final highlight = Rect.fromLTRB(
        xAt(start),
        0,
        xAt(end),
        size.height,
      );
      canvas.drawRect(
        highlight,
        Paint()..color = color.withValues(alpha: 0.08),
      );
    }

    final line = Path();
    final area = Path()..moveTo(xAt(0), size.height);
    for (var i = 0; i < values.length; i++) {
      final point = Offset(xAt(i), yAt(values[i]));
      if (i == 0) {
        line.moveTo(point.dx, point.dy);
      } else {
        line.lineTo(point.dx, point.dy);
      }
      area.lineTo(point.dx, point.dy);
    }
    area
      ..lineTo(xAt(values.length - 1), size.height)
      ..close();

    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.26),
            color.withValues(alpha: 0.02),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    _drawDot(canvas, Offset(xAt(start), yAt(values[start])));
    if (end != start) {
      _drawDot(canvas, Offset(xAt(end), yAt(values[end])));
    }
  }

  void _drawDot(Canvas canvas, Offset center) {
    canvas.drawCircle(center, 3.6, Paint()..color = surfaceColor);
    canvas.drawCircle(
      center,
      3.6,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  /// Clamps [value] into `0..max` while keeping the `int` type.
  int _clampIndex(int value, int max) {
    if (value < 0) {
      return 0;
    }
    return value > max ? max : value;
  }

  @override
  bool shouldRepaint(covariant _AssetTrendPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.top != top ||
        oldDelegate.bottom != bottom ||
        oldDelegate.spanStart != spanStart ||
        oldDelegate.spanEnd != spanEnd ||
        oldDelegate.color != color;
  }
}

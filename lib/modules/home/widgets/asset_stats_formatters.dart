import 'package:flutter/material.dart';

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

/// Formats a signed delta, keeping the `+` sign for gains.
String formatAssetDelta(int delta) {
  return '${delta > 0 ? '+' : ''}${formatAssetValue(delta)}';
}

/// Formats a per-day average change such as `+3.5/天`.
String formatAssetDailyDelta(double value, {required String perDaySuffix}) {
  final sign = value > 0 ? '+' : '';
  if (value == value.roundToDouble()) {
    return '$sign${formatAssetValue(value.round())}$perDaySuffix';
  }
  if (value.abs() >= 100) {
    return '$sign${formatAssetValue(value.round())}$perDaySuffix';
  }
  return '$sign${value.toStringAsFixed(1)}$perDaySuffix';
}

/// Shortens an ISO date key (`yyyy-MM-dd`) into `MM-dd`.
String formatAssetDayLabel(String? date) {
  if (date == null || date.length < 5) {
    return date ?? '';
  }
  return date.substring(5);
}

/// Resolves the Material icon used when a bundled icon is missing.
IconData assetIconFor(String key) {
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

/// Resolves the accent color used for one asset key.
Color assetColorFor(String key) {
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

/// Color used for a positive delta (gain).
const Color assetGainColor = Color(0xFF2E9E5B);

/// Color used for a negative delta (loss).
const Color assetLossColor = Color(0xFFD2544A);

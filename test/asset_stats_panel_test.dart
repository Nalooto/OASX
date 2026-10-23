import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:oasx/modules/home/models/asset_stats_models.dart';
import 'package:oasx/modules/home/widgets/asset_stats_panel.dart';
import 'package:oasx/modules/home/widgets/asset_trend_sheet.dart';
import 'package:oasx/translation/i18n.dart';

/// Builds a payload with [dayCount] daily snapshots ending on 10-22.
ScriptAssetStats buildAssetStats({int dayCount = 8}) {
  final days = <Map<String, dynamic>>[];
  for (var index = 0; index < dayCount; index++) {
    final day = 15 + index;
    days.add({
      'date': '2026-10-${day.toString().padLeft(2, '0')}',
      'updated_at': '2026-10-${day.toString().padLeft(2, '0')}T13:00:00Z',
      'items': {
        'gold': 2051000 + index * 829000,
        'ap': 21658 + index * 342,
        'jade': 21500 - index * 50,
        'soul_jade': 0,
      },
    });
  }
  return ScriptAssetStats.fromJson({
    'script_name': 'oas1',
    'available': true,
    'updated_at': '2026-10-22T13:00:00Z',
    'account': {'name': '无方'},
    'items': [
      {'key': 'gold', 'label': '金币', 'value': 2880000, 'prev': 2051000},
      {'key': 'ap', 'label': '体力', 'value': 22000, 'prev': 21658},
      {'key': 'jade', 'label': '勾玉', 'value': 21000, 'prev': 21500},
      {'key': 'soul_jade', 'label': '魂玉', 'value': 0, 'prev': 0},
    ],
    'days': days,
  });
}

Future<void> pumpPanel(
  WidgetTester tester,
  ScriptAssetStats stats, {
  Size size = const Size(360, 620),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    GetMaterialApp(
      translations: Messages(),
      locale: const Locale('zh', 'CN'),
      fallbackLocale: const Locale('en', 'US'),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(10),
          child: AssetStatsPanel(
            scriptName: 'oas1',
            statsLoader: (_) async => stats,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('compares the last two days by default', (tester) async {
    await pumpPanel(tester, buildAssetStats());

    expect(tester.takeException(), isNull);
    expect(find.text('金币'), findsOneWidget);
    expect(find.text('较 10-21 · 1 天 · 2 涨 / 1 跌'), findsOneWidget);
    expect(find.text('+82.9万'), findsOneWidget);
    expect(find.text('-50'), findsOneWidget);
  });

  testWidgets('quick range expands the comparison span', (tester) async {
    await pumpPanel(tester, buildAssetStats());

    await tester.tap(find.byTooltip('快速区间'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全部记录'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('较 10-15 · 7 天 · 2 涨 / 1 跌'), findsOneWidget);
    expect(find.text('+580.3万'), findsOneWidget);
    expect(find.text('起始'), findsOneWidget);
    expect(find.text('结束'), findsOneWidget);
  });

  testWidgets('tapping a tile opens the per-asset trend sheet', (tester) async {
    await pumpPanel(tester, buildAssetStats());

    await tester.tap(find.text('金币'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(AssetTrendSheet), findsOneWidget);
    expect(find.text('资产趋势'), findsOneWidget);
    expect(find.text('起始值'), findsOneWidget);
    expect(find.text('日均变化'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AssetTrendSheet),
        matching: find.text('+82.9万'),
      ),
      findsOneWidget,
    );
    expect(find.text('+82.9万/天'), findsOneWidget);
  });

  testWidgets('single snapshot shows the comparison hint', (tester) async {
    await pumpPanel(tester, buildAssetStats(dayCount: 1));

    expect(tester.takeException(), isNull);
    expect(find.text('仅有 1 天快照，需至少 2 天才能对比'), findsOneWidget);
  });

  testWidgets('narrow sidebar renders without overflow', (tester) async {
    await pumpPanel(
      tester,
      buildAssetStats(),
      size: const Size(286, 520),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('金币'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:oasx/modules/home/widgets/log_center_panel.dart';
import 'package:oasx/modules/log/log_browser_models.dart';
import 'package:oasx/modules/log/script_log_browser_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(Get.reset);

  Future<void> pumpDetail(
    WidgetTester tester, {
    required ScriptLogBrowserController controller,
    required ScrollController vertical,
    required ScrollController horizontal,
  }) async {
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 420,
            child: LogCenterErrorDetailView(
              controller: controller,
              detailScrollController: vertical,
              detailHorizontalScrollController: horizontal,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  ScriptLogBrowserController buildController(int lineCount) {
    final controller = ScriptLogBrowserController(scriptName: 'demo');
    controller.activeTab.value = ScriptLogBrowserTab.error;
    controller.errorDetailVisible.value = true;
    controller.selectedErrorDetail.value = const ScriptErrorLogDetail(
      id: 'demo_1',
      directory: 'demo_1',
      scriptName: 'demo',
      timestampMs: 0,
      time: '2026-06-01T12:00:00.000',
      legacy: false,
      log: ScriptErrorLogText(
        fileName: 'log.txt',
        content: '',
        size: 0,
        limitBytes: 262144,
        truncated: false,
      ),
      images: <ScriptErrorImageInfo>[],
    );
    controller.selectedErrorLogLines.assignAll(
      List<String>.generate(lineCount, (index) => 'stack line $index'),
    );
    return controller;
  }

  testWidgets('error detail virtualizes long log bodies', (tester) async {
    final controller = buildController(4000);
    final vertical = ScrollController();
    final horizontal = ScrollController();
    addTearDown(vertical.dispose);
    addTearDown(horizontal.dispose);

    await pumpDetail(
      tester,
      controller: controller,
      vertical: vertical,
      horizontal: horizontal,
    );

    final rendered = find.byType(LogCenterLogText).evaluate().length;
    expect(rendered, lessThan(120));
    expect(vertical.hasClients, isTrue);
    expect(vertical.position.maxScrollExtent, greaterThan(0));
  });

  testWidgets('error detail keeps the header pinned while scrolling',
      (tester) async {
    final controller = buildController(400);
    final vertical = ScrollController();
    final horizontal = ScrollController();
    addTearDown(vertical.dispose);
    addTearDown(horizontal.dispose);

    await pumpDetail(
      tester,
      controller: controller,
      vertical: vertical,
      horizontal: horizontal,
    );

    expect(vertical.position.maxScrollExtent, greaterThan(0));
    vertical.jumpTo(vertical.position.maxScrollExtent);
    await tester.pump();

    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.text('stack line 399'), findsNothing);
  });
}

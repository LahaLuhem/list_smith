/// Scenario: scrolling a bare `ListView.builder` (the attribution control).
///
/// The same item widget and scroll as `isp_scroll`, but over a plain `ListView.builder` with no
/// list_smith and no ISP. The frame-cost delta from `isp_scroll` is what list_smith-over-ISP adds on
/// top of a plain list (ISP's load-more plus list_smith's wrapping).
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/frame_scenario.dart';
import 'support/host_frame.dart';
import 'support/scroll_bench_item.dart';

const _iterations = int.fromEnvironment('ITERATIONS', defaultValue: 10);
const _totalItems = int.fromEnvironment('TOTAL_ITEMS', defaultValue: 2000);
const _outputPath = String.fromEnvironment('OUTPUT');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('scrolling a bare ListView.builder (control)', (tester) async {
    await tester.pumpWidget(
      HostFrame(
        child: ListView.builder(
          itemCount: _totalItems,
          itemBuilder: (_, index) => ScrollBenchItem(index: index),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));

    final summary = await captureFrames(binding, () async {
      await flingThrough(tester, scrollable: find.byType(Scrollable).first, passes: _iterations);
    });

    binding.reportData = <String, dynamic>{
      'output_path': _outputPath,
      'records': <Map<String, dynamic>>[
        buildFrameRecord(scenario: 'bare_listview', summary: summary),
      ],
    };
  });
}

/// Scenario: scrolling a list_smith sync list, with ids so its rows are keyed and held still.
///
/// The same items and scroll as `bare_listview`, so the gap between them is what `.sync` adds.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:list_smith/list_smith.dart';

import 'support/frame_scenario.dart';
import 'support/host_frame.dart';
import 'support/scroll_bench_item.dart';

const _iterations = int.fromEnvironment('ITERATIONS', defaultValue: 10);
const _totalItems = int.fromEnvironment('TOTAL_ITEMS', defaultValue: 2000);
const _outputPath = String.fromEnvironment('OUTPUT');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('scrolling a list_smith sync list', (tester) async {
    await tester.pumpWidget(
      HostFrame(
        child: ListSmith<int>.sync(
          items: List<int>.generate(_totalItems, (index) => index),
          itemIdGetter: (item) => item,
          searchBy: (_, _) => true,
          itemBuilder: (_, item, _) => ScrollBenchItem(index: item),
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
        buildFrameRecord(scenario: 'sync_scroll', iterations: _iterations, summary: summary),
      ],
    };
  });
}

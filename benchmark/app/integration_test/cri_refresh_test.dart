/// Scenario: pull-to-refresh on a list_smith async list (custom_refresh_indicator under the hood).
///
/// Captures per-frame build/raster timing across full refresh cycles (drag past the arm threshold,
/// release, run onRefresh, settle back), so the cost of CRI's animation plus list_smith's refresh
/// wiring shows up as real frames. Unlike the scroll pair there is no bare control: pull-to-refresh is
/// the CRI feature itself, so this stands alone as the per-frame cost of a refresh cycle (an
/// upstream-CRI regression tripwire and a build-vs-buy signal on hand-rolling the indicator).
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:list_smith/list_smith.dart';

import 'support/frame_scenario.dart';
import 'support/host_frame.dart';
import 'support/scroll_bench_item.dart';

const _iterations = int.fromEnvironment('ITERATIONS', defaultValue: 10);
const _pageSize = int.fromEnvironment('PAGE_SIZE', defaultValue: 20);
const _outputPath = String.fromEnvironment('OUTPUT');

// The loading indicator animates forever, so the first page is settled with fixed pumps.
const _warmupPumps = 10;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('pull-to-refresh on a list_smith async list (CRI)', (tester) async {
    Future<List<int>> fetchPage(int pageIndex, int pageSize) async =>
        List<int>.generate(pageSize, (index) => pageIndex * pageSize + index);

    await tester.pumpWidget(
      HostFrame(
        child: ListSmith<int>.async(
          fetchPage: fetchPage,
          pageSize: _pageSize,
          pullToRefresh: true,
          itemBuilder: (_, item, _) => ScrollBenchItem(index: item),
        ),
      ),
    );
    for (var i = 0; i < _warmupPumps; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    final summary = await captureFrames(binding, () async {
      await refreshThrough(tester, scrollable: find.byType(Scrollable).first, passes: _iterations);
    });

    binding.reportData = <String, dynamic>{
      'output_path': _outputPath,
      'records': <Map<String, dynamic>>[
        buildFrameRecord(scenario: 'cri_refresh', summary: summary),
      ],
    };
  });
}

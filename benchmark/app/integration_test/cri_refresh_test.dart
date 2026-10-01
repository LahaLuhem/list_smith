/// Scenario: pull-to-refresh on a list_smith async list (custom_refresh_indicator under the hood).
///
/// Per-frame build and raster timing across full cycles: pull past the arm threshold, release, settle.
/// No bare control, unlike the scroll pair, since pull-to-refresh is the whole of what CRI does. So
/// it stands alone as the cost of one cycle, a tripwire for upstream CRI regressions and an input to
/// build-vs-buy.
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

// Fixed pumps settle the 1st page, so every run warms up over the same frames.
const _warmupPumps = 10;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('pull-to-refresh on a list_smith async list (CRI)', (tester) async {
    Future<List<int>> fetchPage(PageRequest request) async => List<int>.generate(
      request.pageSize,
      (index) => request.pageIndex * request.pageSize + index,
    );

    await tester.pumpWidget(
      HostFrame(
        child: ListSmith<int>.async(
          fetchPage: PageFetcher(fetchPage),
          itemIdGetter: (item) => item,
          pageSize: _pageSize,
          refresh: const PullToRefresh(),
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

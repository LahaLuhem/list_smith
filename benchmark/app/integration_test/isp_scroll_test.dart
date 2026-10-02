/// Scenario: scrolling a list_smith async list.
///
/// Per-frame build and raster timing while flinging through many pages, so the near-end load-more and
/// the rest of the paging show up as real frames. This minus `bare_listview` is list_smith's share. The
/// id keeps its `isp_scroll` name from before list_smith paged on its own, so the history lines up.
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

  testWidgets('scrolling a list_smith async list', (tester) async {
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
          refresh: const NoRefresh(),
          itemBuilder: (_, item, _) => ScrollBenchItem(index: item),
        ),
      ),
    );
    for (var i = 0; i < _warmupPumps; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    final summary = await captureFrames(binding, () async {
      await flingThrough(tester, scrollable: find.byType(Scrollable).first, passes: _iterations);
    });

    binding.reportData = <String, dynamic>{
      'output_path': _outputPath,
      'records': <Map<String, dynamic>>[buildFrameRecord(scenario: 'isp_scroll', summary: summary)],
    };
  });
}

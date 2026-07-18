/// Scenario: scrolling a list_smith async list (ISP under the hood).
///
/// Captures per-frame build/raster timing while flinging through many pages, so the cost of ISP's
/// index-triggered load-more plus list_smith's wrapping shows up as real frames. Paired with
/// `bare_listview` (the same item widget + scroll over a plain `ListView.builder`) for attribution:
/// list_smith-over-ISP minus bare minus the ~0 micro overhead is ISP's own share.
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

  testWidgets('scrolling a list_smith async list (ISP)', (tester) async {
    Future<List<int>> fetchPage(int pageIndex, int pageSize) async =>
        List<int>.generate(pageSize, (index) => pageIndex * pageSize + index);

    await tester.pumpWidget(
      HostFrame(
        child: ListSmith<int>.async(
          fetchPage: PageFetcher(fetchPage),
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

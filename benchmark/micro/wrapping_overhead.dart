/// Micro-benchmark: list_smith's per-`getNextPageKey` overhead on top of ISP.
///
/// Each time ISP asks for the next page key, list_smith rebuilds a `List<int>` of the item count of
/// every page loaded so far and runs the end policy over it (`_nextPageKey` in
/// `async_list_view.dart`). This measures that ISP-agnostic core as the loaded-page count grows,
/// confirming the wrapping costs ~nothing (BICC's `check_once_overhead` analogue).
library;

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:list_smith/src/data/pagination/extensions/pagination_end_policy_resolver_extension.dart';
import 'package:list_smith/src/data/pagination/models/pagination_end_policy.dart';

import '../harness/result_writer.dart';
import '../harness/scenario_args.dart';

/// Loaded-page counts the per-key overhead is measured against; the pivot for the curve.
const _pageCounts = <int>[1, 10, 100];
const _itemsPerPage = 20;

final class _WrappingOverhead extends BenchmarkBase {
  _WrappingOverhead(this.pageCount) : super('wrapping_overhead_p$pageCount');

  final int pageCount;
  late final List<List<int>> _pages;
  var lastKey = 0;

  static const _endPolicy = StopOnEmptyPagesPolicy();

  @override
  void setup() => _pages = List<List<int>>.generate(
    pageCount,
    (_) => List<int>.filled(_itemsPerPage, 0),
    growable: false,
  );

  @override
  void run() {
    // Mirror _nextPageKey's per-call work: rebuild the page-item-counts, then run the end policy.
    final pageItemCounts = _pages.map((page) => page.length).toList(growable: false);
    lastKey = _endPolicy.hasReachedEnd(pageItemCounts) ? -1 : _pages.length;
  }
}

Future<void> main(List<String> argv) async {
  final args = ScenarioArgs.parse(argv);

  final writer = await ResultWriter.open(
    outputPath: args.outputPath,
    scenario: 'wrapping_overhead',
    sdkVersion: ScenarioArgs.sdkVersion,
    packageVersion: args.packageVersion,
    gitSha: args.gitSha,
  );

  for (var i = 0; i < args.iterations; i++) {
    for (final pageCount in _pageCounts) {
      final benchmark = _WrappingOverhead(pageCount);

      forceGc();
      final microseconds = benchmark.measure();

      writer.writeRecord(
        iteration: i,
        samples: {
          'microseconds_per_key_computation': [microseconds],
        },
        summary: {
          'page_count': pageCount,
          'microseconds_per_key_computation': microseconds,
          'last_key': benchmark.lastKey,
        },
      );
    }
  }

  await writer.close();
}

/// Micro-benchmark: [resolveSyncSearch] cost as the in-memory list grows.
///
/// This is choke point #2 from the benchmarking plan: `SyncListView` re-runs `resolveSyncSearch`
/// (an `items.where(predicate).toList()`, O(n) times the predicate cost) synchronously on every
/// committed query. Measuring it AOT across a range of list sizes puts a trustworthy microseconds
/// figure on where a big in-memory list crosses the frame budget. The predicate is a naive
/// case-insensitive `contains` (a `toLowerCase()` allocation per item), representative of what a
/// consumer typically writes.
library;

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:list_smith/src/data/search/utils/sync_search_resolver.dart';

import '../harness/result_writer.dart';
import '../harness/scenario_args.dart';

/// In-memory list sizes the resolver is measured against; the pivot for the scaling curve.
const _listSizes = <int>[1000, 10000, 100000];

final class _SyncSearchScaling extends BenchmarkBase {
  _SyncSearchScaling(this.listSize) : super('sync_search_scaling_n$listSize');

  final int listSize;
  late final List<String> _items;
  var lastMatchCount = 0;

  @override
  void setup() =>
      _items = List<String>.generate(listSize, (i) => 'Row $i label ${i % 100}', growable: false);

  @override
  void run() {
    final result = resolveSyncSearch(_items, _matches, 'label 7', 0);
    lastMatchCount = result.visibleItems.length;
  }

  static bool _matches(String item, String query) => item.toLowerCase().contains(query);
}

Future<void> main(List<String> argv) async {
  final args = ScenarioArgs.parse(argv);

  final writer = await ResultWriter.open(
    outputPath: args.outputPath,
    scenario: 'sync_search_scaling',
    sdkVersion: ScenarioArgs.sdkVersion,
    packageVersion: args.packageVersion,
    gitSha: args.gitSha,
  );

  for (var i = 0; i < args.iterations; i++) {
    for (final listSize in _listSizes) {
      final benchmark = _SyncSearchScaling(listSize);

      forceGc();
      final microseconds = benchmark.measure();

      writer.writeRecord(
        iteration: i,
        samples: {
          'microseconds_per_resolve': [microseconds],
        },
        summary: {
          'list_size': listSize,
          'microseconds_per_resolve': microseconds,
          'matched_count': benchmark.lastMatchCount,
        },
      );
    }
  }

  await writer.close();
}

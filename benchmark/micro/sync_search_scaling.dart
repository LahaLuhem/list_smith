/// Micro-benchmark: [resolveSyncSearch] cost as the in-memory list grows.
///
/// `SyncListView` re-runs `resolveSyncSearch` synchronously on every committed query, a `where` over
/// every item. Measured AOT across a range of sizes, so the microseconds figure says where a big
/// in-memory list crosses the frame budget. The predicate is a naive case-insensitive `contains`, one
/// `toLowerCase()` per item, which is what a consumer typically writes.
library;

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:list_smith/src/data/search/utils/sync_search_resolver.dart';

import '../harness/measure.dart';
import '../harness/result_writer.dart';
import '../harness/scenario_arguments.dart';

/// In-memory list sizes the resolver is measured against. The pivot for the scaling curve.
const _listSizes = <int>[1000, 10000, 100000];

final class _SyncSearchScaling extends BenchmarkBase {
  new(this.listSize) : super('sync_search_scaling_n$listSize');

  final int listSize;
  late final List<String> _items;
  var lastMatchCount = 0;

  @override
  void setup() =>
      _items = List<String>.generate(listSize, (i) => 'Row $i label ${i % 100}', growable: false);

  @override
  void run() {
    final searchResult = resolveSyncSearch(_items, _matches, 'label 7', 0);
    lastMatchCount = searchResult.visibleItems.length;
  }

  static bool _matches(String item, String query) => item.toLowerCase().contains(query);
}

Future<void> main(List<String> arguments) async {
  final scenarioArguments = ScenarioArguments.parse(arguments);

  final writer = await ResultWriter.open(
    outputPath: scenarioArguments.outputPath,
    scenario: 'sync_search_scaling',
    sdkVersion: ScenarioArguments.sdkVersion,
    packageVersion: scenarioArguments.packageVersion,
    gitSha: scenarioArguments.gitSha,
  );

  for (var i = 0; i < scenarioArguments.iterations; i++) {
    for (final listSize in _listSizes) {
      final benchmark = _SyncSearchScaling(listSize);

      final microseconds = measureWindowed(benchmark, millis: scenarioArguments.measureMillis);

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

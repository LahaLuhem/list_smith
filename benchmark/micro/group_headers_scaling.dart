/// Micro-benchmark: [resolveGroupHeaders] cost as the loaded list grows.
///
/// Runs per item on every build of a grouped list, page by page, so a slower scan trips the gate.
library;

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:list_smith/src/data/grouping/models/group_order_policy.dart';
import 'package:list_smith/src/data/grouping/utils/grouping_resolver.dart';

import '../harness/measure.dart';
import '../harness/result_writer.dart';
import '../harness/scenario_arguments.dart';

/// Loaded-item counts the scan is measured against. The pivot for the scaling curve.
const _itemCounts = <int>[1000, 10000, 100000];

/// Items per page, so the source is paged like the real one.
const _pageSize = 100;

/// Small groups, so the pass opens a run often.
const _groupSize = 10;

final class _GroupHeadersScaling(final int itemCount) extends BenchmarkBase {
  this : super('group_headers_scaling_n$itemCount');

  late final List<List<int>> _pages;
  var lastHeaderCount = 0;

  @override
  void setup() => _pages = List<List<int>>.generate(
    itemCount ~/ _pageSize,
    (page) => List<int>.generate(_pageSize, (index) => page * _pageSize + index, growable: false),
    growable: false,
  );

  @override
  void run() {
    // Grouped pages, so nothing gathers. This times the header pass, which is also the order check.
    final (:headers, gatheredItems: _) = resolveGroupHeaders(
      _pages,
      _groupKey,
      const RepairHeadersPolicy(),
    );
    lastHeaderCount = headers.length;
  }

  static Object _groupKey(int item) => item ~/ _groupSize;
}

Future<void> main(List<String> arguments) async {
  final scenarioArguments = ScenarioArguments.parse(arguments);

  final writer = await ResultWriter.open(
    outputPath: scenarioArguments.outputPath,
    scenario: 'group_headers_scaling',
    sdkVersion: ScenarioArguments.sdkVersion,
    packageVersion: scenarioArguments.packageVersion,
    gitSha: scenarioArguments.gitSha,
  );

  for (var i = 0; i < scenarioArguments.iterations; i++) {
    for (final itemCount in _itemCounts) {
      final benchmark = _GroupHeadersScaling(itemCount);

      final microseconds = measureWindowed(benchmark, millis: scenarioArguments.measureMillis);

      writer.writeRecord(
        iteration: i,
        samples: {
          'microseconds_per_scan': [microseconds],
        },
        summary: {
          'item_count': itemCount,
          'microseconds_per_scan': microseconds,
          'header_count': benchmark.lastHeaderCount,
        },
      );
    }
  }

  await writer.close();
}

/// Micro-benchmark: [headerFlagsByFirstSighting] cost as the loaded list grows.
///
/// Runs per item on every `PagedView` build, over the lazy flatten of the pages, so a slower scan
/// trips the gate. Groups are runs of ten.
library;

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:list_smith/src/data/grouping/utils/grouping_resolver.dart';

import '../harness/result_writer.dart';
import '../harness/scenario_args.dart';

/// Loaded-item counts the scan is measured against. The pivot for the scaling curve.
const _itemCounts = <int>[1000, 10000, 100000];

/// Items per page, so the source is a lazy flatten of pages like the real one.
const _pageSize = 100;

/// Items per group. Every tenth item opens a run.
const _groupSize = 10;

final class _HeaderFlagsScaling extends BenchmarkBase {
  new(this.itemCount) : super('header_flags_scaling_n$itemCount');

  final int itemCount;
  late final List<List<int>> _pages;
  var lastFlagCount = 0;

  @override
  void setup() => _pages = List<List<int>>.generate(
    itemCount ~/ _pageSize,
    (page) => List<int>.generate(_pageSize, (index) => page * _pageSize + index, growable: false),
    growable: false,
  );

  @override
  void run() {
    final flags = headerFlagsByFirstSighting(_pages.expand((page) => page), _groupKey);
    lastFlagCount = flags.length;
  }

  static Object _groupKey(int item) => item ~/ _groupSize;
}

Future<void> main(List<String> argv) async {
  final args = ScenarioArgs.parse(argv);

  final writer = await ResultWriter.open(
    outputPath: args.outputPath,
    scenario: 'header_flags_scaling',
    sdkVersion: ScenarioArgs.sdkVersion,
    packageVersion: args.packageVersion,
    gitSha: args.gitSha,
  );

  for (var i = 0; i < args.iterations; i++) {
    for (final itemCount in _itemCounts) {
      final benchmark = _HeaderFlagsScaling(itemCount);

      forceGc();
      final microseconds = benchmark.measure();

      writer.writeRecord(
        iteration: i,
        samples: {
          'microseconds_per_scan': [microseconds],
        },
        summary: {
          'item_count': itemCount,
          'microseconds_per_scan': microseconds,
          'flag_count': benchmark.lastFlagCount,
        },
      );
    }
  }

  await writer.close();
}

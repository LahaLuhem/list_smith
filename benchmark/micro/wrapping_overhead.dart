/// Micro-benchmark: list_smith's per-page end check.
library;

import 'dart:collection';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:list_smith/src/data/pagination/models/end_context.dart';
import 'package:list_smith/src/data/pagination/models/loaded_page.dart';
import 'package:list_smith/src/data/pagination/models/pagination_end_policy.dart';

import '../harness/measure.dart';
import '../harness/result_writer.dart';
import '../harness/scenario_arguments.dart';

/// Loaded-page counts the per-key overhead is measured against. The pivot for the curve.
const _pageCounts = <int>[1, 10, 100];
const _itemsPerPage = 20;

final class _WrappingOverhead(final int pageCount) extends BenchmarkBase {
  this : super('wrapping_overhead_p$pageCount');

  late final List<LoadedPage<int>> _pages;
  var lastKey = 0;

  static const _endPolicy = StopOnEmptyPagesPolicy();

  @override
  void setup() => _pages = List.generate(
    pageCount,
    (_) => LoadedPage(items: List<int>.filled(_itemsPerPage, 0), readStamp: 0),
    growable: false,
  );

  @override
  void run() {
    // Mirrors _nextPageIndex.
    final pageItemCounts = UnmodifiableListView(_pages.map((page) => page.items.length));
    final context = EndContext(pageItemCounts: pageItemCounts, pageSize: _itemsPerPage);
    lastKey = _endPolicy.hasReachedEnd(context) ? -1 : _pages.length;
  }
}

Future<void> main(List<String> arguments) async {
  final scenarioArguments = ScenarioArguments.parse(arguments);

  final writer = await ResultWriter.open(
    outputPath: scenarioArguments.outputPath,
    scenario: 'wrapping_overhead',
    sdkVersion: ScenarioArguments.sdkVersion,
    packageVersion: scenarioArguments.packageVersion,
    gitSha: scenarioArguments.gitSha,
  );

  for (var i = 0; i < scenarioArguments.iterations; i++) {
    for (final pageCount in _pageCounts) {
      final benchmark = _WrappingOverhead(pageCount);

      final microseconds = measureWindowed(benchmark, millis: scenarioArguments.measureMillis);

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

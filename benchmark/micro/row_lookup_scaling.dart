/// Micro-benchmark: finding every built row again on a rebuild, as the loaded list grows.
///
/// Pages and items match `dedup_scaling`'s, so the curves read side by side.
library;

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:collection/collection.dart';
import 'package:list_smith/src/data/presentation/utils/row_lookup.dart';

import '../harness/measure.dart';
import '../harness/result_writer.dart';
import '../harness/scenario_arguments.dart';

const _itemCounts = [1000, 10000, 100000];
const _itemsPerPage = 20;

/// Rows a list keeps built around its viewport.
const _builtRows = 30;

/// One rebuild: a fresh [RowLookup] over the new pages, then every built row found again and re-keyed.
final class _RowLookupScaling(final int itemCount, final _Change change) extends BenchmarkBase {
  this : super('row_lookup_scaling_n$itemCount');

  late final List<List<_Item>> _pages;
  late final List<({int id, int lastIndex})> _rows;
  var lastFoundCount = 0;

  @override
  void setup() {
    final loadedPages = List<List<_Item>>.generate(
      itemCount ~/ _itemsPerPage,
      (page) => List<_Item>.generate(
        _itemsPerPage,
        (index) => _Item(page * _itemsPerPage + index),
        growable: false,
      ),
      growable: false,
    );
    final topRows = List.generate(_builtRows, (index) => (id: index, lastIndex: index));
    switch (change) {
      case .pageAppended:
        _pages = [
          ...loadedPages,
          List.generate(_itemsPerPage, (index) => _Item(itemCount + index), growable: false),
        ];
        _rows = List.generate(_builtRows, (index) {
          final id = itemCount - _builtRows + index;

          return (id: id, lastIndex: id);
        });
      case .itemOnTop:
        _pages = [
          [const _Item(-1), ...loadedPages.first],
          ...loadedPages.skip(1),
        ];
        _rows = topRows;
      case .rowRemoved:
        _pages = [
          [...loadedPages.first]..removeAt(_builtRows ~/ 2),
          ...loadedPages.skip(1),
        ];
        _rows = topRows;
    }
  }

  @override
  void run() {
    final rowLookup = RowLookup(_pages, (item) => item.id);
    var foundCount = 0;
    for (final row in _rows) {
      final index = rowLookup.indexOf(row.id, row.lastIndex);
      // Keying the rebuilt row reads its item again, so that read is part of the rebuild too.
      if (index != null && rowLookup.itemAt(index).id == row.id) foundCount++;
    }

    lastFoundCount = foundCount;
  }
}

/// What changed since the rows were built.
enum _Change(final String metricKey) {
  /// The user scrolled to the bottom, and the page that brought in moves nothing.
  pageAppended('page_appended_microseconds_per_pass'),

  /// The user sits at the top, and every row there now sits 1 lower than it was built.
  itemOnTop('item_on_top_microseconds_per_pass'),

  /// A row halfway down the built ones went, so its lookup builds the id map.
  rowRemoved('row_removed_microseconds_per_pass'),
}

/// A reference-identity item with an [id], the shape `itemIdGetter` keys on.
final class const _Item(final int id);

Future<void> main(List<String> arguments) async {
  final scenarioArguments = ScenarioArguments.parse(arguments);

  final writer = await ResultWriter.open(
    outputPath: scenarioArguments.outputPath,
    scenario: 'row_lookup_scaling',
    sdkVersion: ScenarioArguments.sdkVersion,
    packageVersion: scenarioArguments.packageVersion,
    gitSha: scenarioArguments.gitSha,
  );

  for (var i = 0; i < scenarioArguments.iterations; i++) {
    for (final itemCount in _itemCounts) {
      final benchmarks = _Change.values
          .map((change) => _RowLookupScaling(itemCount, change))
          .toList(growable: false);
      final microsecondsByMetric = Map.fromEntries(
        benchmarks.map(
          (benchmark) => MapEntry(
            benchmark.change.metricKey,
            measureWindowed(benchmark, millis: scenarioArguments.measureMillis),
          ),
        ),
      );

      writer.writeRecord(
        iteration: i,
        samples: microsecondsByMetric.map(
          (metric, microseconds) => MapEntry(metric, [microseconds]),
        ),
        summary: {
          'item_count': itemCount,
          ...microsecondsByMetric,
          'found_rows': benchmarks.map((benchmark) => benchmark.lastFoundCount).sum,
        },
      );
    }
  }

  await writer.close();
}

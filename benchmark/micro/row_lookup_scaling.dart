/// Micro-benchmark: finding every built row again on a rebuild, as the loaded list grows.
///
/// A page landing at the end moves no row, so each one is found at its last index. An item landing on
/// top moves them all, so the 1st lookup builds the id map. Pages and items match `dedup_scaling`'s,
/// so the curves read side by side.
library;

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:list_smith/src/data/pagination/models/paging_state.dart';
import 'package:list_smith/src/data/presentation/utils/row_lookup.dart';

import '../harness/measure.dart';
import '../harness/result_writer.dart';
import '../harness/scenario_arguments.dart';

const _itemCounts = [1000, 10000, 100000];
const _itemsPerPage = 20;

/// Rows a list keeps built around its viewport.
const _builtRows = 30;

/// One rebuild: a fresh [RowLookup] over the new pages, then every built row found again and re-keyed.
final class _RowLookupScaling(final int itemCount, {required final bool isItemOnTop})
    extends BenchmarkBase {
  this : super('row_lookup_scaling_n$itemCount');

  late final List<LoadedPage<_Item>> _pages;
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
    final List<List<_Item>> shownPages;
    if (isItemOnTop) {
      // The user sits at the top, and every row there now sits 1 lower than it was built.
      shownPages = [
        [const _Item(-1), ...loadedPages.first],
        ...loadedPages.skip(1),
      ];
      _rows = List.generate(_builtRows, (index) => (id: index, lastIndex: index));
    } else {
      // The user scrolled to the bottom, and the page that brought in moves nothing.
      shownPages = [
        ...loadedPages,
        List.generate(_itemsPerPage, (index) => _Item(itemCount + index), growable: false),
      ];
      _rows = List.generate(_builtRows, (index) {
        final id = itemCount - _builtRows + index;

        return (id: id, lastIndex: id);
      });
    }
    _pages = shownPages.map((items) => (items: items, readStamp: 0)).toList(growable: false);
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
      final append = _RowLookupScaling(itemCount, isItemOnTop: false);
      final appendMicroseconds = measureWindowed(append, millis: scenarioArguments.measureMillis);
      final itemOnTop = _RowLookupScaling(itemCount, isItemOnTop: true);
      final itemOnTopMicroseconds = measureWindowed(
        itemOnTop,
        millis: scenarioArguments.measureMillis,
      );

      writer.writeRecord(
        iteration: i,
        samples: {
          'page_appended_microseconds_per_pass': [appendMicroseconds],
          'item_on_top_microseconds_per_pass': [itemOnTopMicroseconds],
        },
        summary: {
          'item_count': itemCount,
          'page_appended_microseconds_per_pass': appendMicroseconds,
          'item_on_top_microseconds_per_pass': itemOnTopMicroseconds,
          'found_rows': append.lastFoundCount + itemOnTop.lastFoundCount,
        },
      );
    }
  }

  await writer.close();
}

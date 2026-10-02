/// Micro-benchmark: the edit layer's display pass as the loaded list grows.
///
/// 10 new items join groups spread across a grouped list, the case that has to find where each group
/// starts. Pages and items match `dedup_scaling`'s, so the 2 curves read side by side.
library;

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:list_smith/src/data/edits/typedefs/item_edit.dart';
import 'package:list_smith/src/data/edits/utils/edit_resolver.dart';
import 'package:list_smith/src/data/pagination/models/loaded_page.dart';

import '../harness/measure.dart';
import '../harness/result_writer.dart';
import '../harness/scenario_arguments.dart';

/// Loaded item counts the pass is measured against. The pivot for the scaling curve, `dedup_scaling`'s.
const _itemCounts = [1000, 10000, 100000];
const _itemsPerPage = 20;
const _groupSize = 100;
const _newItemCount = 10;

/// Resolves the display pages, the pass `_displayFor` runs while there are edits.
final class _EditLayerScaling(final int itemCount) extends BenchmarkBase {
  this : super('edit_layer_scaling_n$itemCount');

  late final List<LoadedPage<_Item>> _pages;
  late final Map<Object, ItemEdit<_Item>> _edits;
  var lastRowCount = 0;

  @override
  void setup() {
    _pages = List.generate(
      itemCount ~/ _itemsPerPage,
      (page) => LoadedPage(
        items: List<_Item>.generate(
          _itemsPerPage,
          (index) => _Item.at(page * _itemsPerPage + index),
          growable: false,
        ),
        readStamp: 0,
      ),
      growable: false,
    );
    final groupStride = itemCount ~/ (_newItemCount * _groupSize);
    _edits = Map.fromEntries(
      Iterable.generate(_newItemCount, (index) {
        final newItem = _Item(itemCount + index, index * groupStride);

        return MapEntry(newItem.id, (item: newItem, stamp: index + 1)); // newer than every page
      }),
    );
  }

  @override
  void run() {
    final displayPages = resolveDisplayPages(
      pages: _pages,
      edits: _edits,
      itemIdGetter: (item) => item.id,
      groupOf: (item) => item.group,
      acceptsNewItems: true,
    ).pages;

    lastRowCount = displayPages.fold(0, (total, page) => total + page.items.length);
  }
}

/// A reference-identity item, the shape `itemIdGetter` keys on, in groups of [_groupSize].
final class const _Item(final int id, final int group) {
  const new at(int id) : this(id, id ~/ _groupSize);
}

Future<void> main(List<String> arguments) async {
  final scenarioArguments = ScenarioArguments.parse(arguments);

  final writer = await ResultWriter.open(
    outputPath: scenarioArguments.outputPath,
    scenario: 'edit_layer_scaling',
    sdkVersion: ScenarioArguments.sdkVersion,
    packageVersion: scenarioArguments.packageVersion,
    gitSha: scenarioArguments.gitSha,
  );

  for (var i = 0; i < scenarioArguments.iterations; i++) {
    for (final itemCount in _itemCounts) {
      final benchmark = _EditLayerScaling(itemCount);

      final microseconds = measureWindowed(benchmark, millis: scenarioArguments.measureMillis);

      writer.writeRecord(
        iteration: i,
        samples: {
          'microseconds_per_pass': [microseconds],
        },
        summary: {
          'item_count': itemCount,
          'microseconds_per_pass': microseconds,
          'row_count': benchmark.lastRowCount,
        },
      );
    }
  }

  await writer.close();
}

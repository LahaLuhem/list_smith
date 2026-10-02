/// Micro-benchmark: the async list's overlap de-dup cost as the loaded list grows.
///
/// Measured over pages that don't overlap, the common case where de-dup collapses nothing. That's
/// the worst case for the pass, every item retained so allocation is maximal, and the penalty you pay
/// for not having the problem.
///
/// The cost scales with the whole loaded list, not the incoming page: `filterItems` re-walks every loaded
/// page. It runs the real `PagingState.filterItems`, the call `_displayFor`'s no-edit path makes.
library;

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:list_smith/src/data/pagination/models/loaded_page.dart';
import 'package:list_smith/src/data/pagination/models/paging_state.dart';

import '../harness/measure.dart';
import '../harness/result_writer.dart';
import '../harness/scenario_arguments.dart';

/// Loaded item counts the de-dup is measured against, `sync_search_scaling`'s so the curves read side
/// by side.
const _itemCounts = [1000, 10000, 100000];
const _itemsPerPage = 20;

/// Re-de-dup every loaded page through `filterItems`.
final class _DedupScaling(final int itemCount) extends BenchmarkBase {
  this : super('dedup_scaling_n$itemCount');

  late final PagingState<_Item> _state;
  var lastCount = 0;

  @override
  void setup() {
    _state = PagingState(
      pages: _pagesOf(itemCount)
          .map((items) => LoadedPage(items: items, readStamp: 0))
          .toList(growable: false),
    );
  }

  @override
  void run() {
    final seenIds = <Object>{};
    final filtered = _state.filterItems((item) => seenIds.add(_idOf(item)));

    lastCount = filtered.pages!.fold(0, (total, page) => total + page.items.length);
  }
}

/// A reference-identity item keyed by [id], the shape `itemIdGetter` keys on (fresh objects, no `==`).
final class const _Item(final int id);

int _idOf(_Item item) => item.id;

/// [itemCount] items laid out in [_itemsPerPage]-sized pages, every id unique so nothing collapses.
List<List<_Item>> _pagesOf(int itemCount) {
  final pageCount = (itemCount / _itemsPerPage).ceil();

  return List<List<_Item>>.generate(
    pageCount,
    (page) => List<_Item>.generate(
      _itemsPerPage,
      (index) => _Item(page * _itemsPerPage + index),
      growable: false,
    ),
    growable: false,
  );
}

Future<void> main(List<String> arguments) async {
  final scenarioArguments = ScenarioArguments.parse(arguments);

  final writer = await ResultWriter.open(
    outputPath: scenarioArguments.outputPath,
    scenario: 'dedup_scaling',
    sdkVersion: ScenarioArguments.sdkVersion,
    packageVersion: scenarioArguments.packageVersion,
    gitSha: scenarioArguments.gitSha,
  );

  for (var i = 0; i < scenarioArguments.iterations; i++) {
    for (final itemCount in _itemCounts) {
      final benchmark = _DedupScaling(itemCount);

      final microseconds = measureWindowed(benchmark, millis: scenarioArguments.measureMillis);

      writer.writeRecord(
        iteration: i,
        samples: {
          'microseconds_per_dedup': [microseconds],
        },
        summary: {
          'item_count': itemCount,
          'microseconds_per_dedup': microseconds,
          'retained_count': benchmark.lastCount,
        },
      );
    }
  }

  await writer.close();
}

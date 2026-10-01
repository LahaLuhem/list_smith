/// Micro-benchmark: the async list's overlap de-dup cost as the loaded list grows.
///
/// Measured over pages that don't overlap, the common case where de-dup collapses nothing. That's
/// the worst case for the pass, every item retained so allocation is maximal, and the penalty you pay
/// for not having the problem.
///
/// The cost scales with the whole loaded list, not the incoming page: `filterItems` re-walks every loaded
/// page and `copyWith` re-wraps each in `List.unmodifiable`. Mirrored in pure Dart here because the
/// real code is a widget method over an ISP `PagingState`, which won't AOT-compile as a plain exe. Keep
/// the mirror in step with `_displayFor`'s no-edit path.
library;

import 'package:benchmark_harness/benchmark_harness.dart';

import '../harness/measure.dart';
import '../harness/result_writer.dart';
import '../harness/scenario_arguments.dart';

/// Loaded item counts the de-dup is measured against, `sync_search_scaling`'s so the curves read side
/// by side.
const _itemCounts = [1000, 10000, 100000];
const _itemsPerPage = 20;

/// Re-de-dup every loaded page and re-wrap, mirroring `filterItems` + `copyWith`.
final class _DedupScaling(final int itemCount) extends BenchmarkBase {
  this : super('dedup_scaling_n$itemCount');

  late final List<List<_Item>> _pages;
  late final List<int> _keys;
  var lastCount = 0;

  @override
  void setup() {
    _pages = _pagesOf(itemCount);
    _keys = List.generate(_pages.length, (index) => index, growable: false);
  }

  @override
  void run() {
    final seenIds = <Object>{};
    // filterItems: pages.map((page) => page.where(predicate).toList()).toList().
    final filtered = _pages
        .map((page) => page.where((item) => seenIds.add(_idOf(item))).toList())
        .toList();
    // copyWith -> PagingStateBase: List.unmodifiable(pages.map(List.unmodifiable)), keys re-wrapped.
    final wrappedPages = List<List<_Item>>.unmodifiable(filtered.map(List<_Item>.unmodifiable));
    List<int>.unmodifiable(_keys);

    lastCount = wrappedPages.fold(0, (total, page) => total + page.length);
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

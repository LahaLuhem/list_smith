/// Micro-benchmark: the async list's overlap de-dup cost as the loaded list grows.
///
/// De-dup is opt-in (a non-null `itemId`); this measures what that opt-in costs when the pages do
/// NOT actually overlap, the common case where de-dup is carried as insurance and collapses nothing.
/// That is both the worst case for the pass (every item is retained, so allocation is maximal) and
/// the "penalty when you don't have the problem" the cost is judged against.
///
/// `_dedupedForDisplay` runs `PagingState.filterItems` per state change, i.e. it re-walks EVERY
/// loaded page (`pages.map((page) => page.where(pred).toList()).toList()`) and then pays `copyWith`'s
/// `List.unmodifiable` re-wrap, so the cost scales with the whole loaded list, not the incoming page.
/// It is mirrored here in pure Dart because the real code is a widget method over an ISP
/// `PagingState`, which can't AOT-compile as a plain exe (the `wrapping_overhead` micro mirrors
/// `_nextPageKey` for the same reason). The headline is the absolute microseconds against a 16 ms
/// frame budget. Keep this mirror in step with `_dedupedForDisplay` and ISP's `filterItems`/`copyWith`
/// if either changes.
library;

import 'package:benchmark_harness/benchmark_harness.dart';

import '../harness/result_writer.dart';
import '../harness/scenario_args.dart';

/// Loaded item counts the de-dup is measured against; the pivot for the scaling curve (matches
/// `sync_search_scaling`'s range so the curves are read side by side).
const _itemCounts = [1000, 10000, 100000];
const _itemsPerPage = 20;

/// Re-de-dup every loaded page and re-wrap, mirroring `filterItems` + `copyWith`.
final class _DedupScaling extends BenchmarkBase {
  _DedupScaling(this.itemCount) : super('dedup_scaling_n$itemCount');

  final int itemCount;
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
    final seen = <Object>{};
    // filterItems: pages.map((page) => page.where(predicate).toList()).toList().
    final filtered = _pages
        .map((page) => page.where((item) => seen.add(_idOf(item))).toList())
        .toList();
    // copyWith -> PagingStateBase: List.unmodifiable(pages.map(List.unmodifiable)), keys re-wrapped.
    final wrappedPages = List<List<_Item>>.unmodifiable(filtered.map(List<_Item>.unmodifiable));
    List<int>.unmodifiable(_keys);

    lastCount = wrappedPages.fold(0, (total, page) => total + page.length);
  }
}

/// A reference-identity item keyed by [id], the shape `itemId` de-dups (fresh objects, no `==`).
final class _Item {
  const _Item(this.id);

  final int id;
}

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

Future<void> main(List<String> argv) async {
  final args = ScenarioArgs.parse(argv);

  final writer = await ResultWriter.open(
    outputPath: args.outputPath,
    scenario: 'dedup_scaling',
    sdkVersion: ScenarioArgs.sdkVersion,
    packageVersion: args.packageVersion,
    gitSha: args.gitSha,
  );

  for (var i = 0; i < args.iterations; i++) {
    for (final itemCount in _itemCounts) {
      final benchmark = _DedupScaling(itemCount);

      forceGc();
      final microseconds = benchmark.measure();

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

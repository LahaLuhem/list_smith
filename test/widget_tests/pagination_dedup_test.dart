// Test-local fixtures share the file with the scenarios that use them.
// ignore_for_file: prefer-match-file-name

import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

import '../support/support.dart';

void main() {
  feature('ListSmith.async pagination dedup', () {
    // Page 1 starts with fresh copies of page 0's last 2 items, the overlap an offset backend gives
    // when its data shifts between fetches. ISP appends pages as they come, and with no `==` only an
    // id key can collapse the copies.
    final overlappingPages = pagedFetcher([
      [_Item(0), _Item(1), _Item(2), _Item(3), _Item(4)],
      [_Item(3), _Item(4), _Item(5), _Item(6), _Item(7)],
    ]);

    // A mid-stream page made only of page 0's ids (fresh objects), then a really new page.
    // De-dup collapses page 1 to nothing for display. The end policy must still see that the backend
    // returned a full page there, or it reads the empty result as end-of-data and never fetches page
    // 2. Page 3 is empty, the real end.
    final allDuplicateMidStreamPages = pagedFetcher([
      [_Item(0), _Item(1), _Item(2), _Item(3), _Item(4)],
      [_Item(0), _Item(1), _Item(2), _Item(3), _Item(4)],
      [_Item(5), _Item(6), _Item(7), _Item(8), _Item(9)],
    ]);

    // The same overlap as [overlappingPages], but served through `searchFetchPage`. De-dup runs on the
    // shared fetch path, so it must behave identically under an active query.
    final overlappingSearchPages = pagedSearchFetcher([
      [_Item(0), _Item(1), _Item(2), _Item(3), _Item(4)],
      [_Item(3), _Item(4), _Item(5), _Item(6), _Item(7)],
    ]);

    scenarioWidgets('de-dup by id collapses an item repeated across a page boundary to one', (
      tester,
    ) async {
      await _pumpPagedList(tester, fetchPage: overlappingPages, itemIdGetter: (item) => item.id);
      await drain(tester, frames: 8);

      // Ids 3 and 4 are returned by both page 0 and page 1. The key collapses each to one.
      check(find.text('item 3').evaluate()).length.equals(1);
      check(find.text('item 4').evaluate()).length.equals(1);
      // Non-overlapping ids are unaffected controls.
      check(find.text('item 0').evaluate()).length.equals(1);
      check(find.text('item 7').evaluate()).length.equals(1);
    });

    scenarioWidgets('an all-duplicate mid-stream page does not end pagination before later pages', (
      tester,
    ) async {
      await _pumpPagedList(
        tester,
        fetchPage: allDuplicateMidStreamPages,
        itemIdGetter: (item) => item.id,
      );
      await drain(tester, frames: 16);

      // Page 1 de-dups to empty, but the backend had more past it: pagination must reach page 2, so
      // its fresh ids render. This is the regression: reading the de-duped gap as end-of-data stops
      // here and ids 5..9 never load.
      check(find.text('item 5').evaluate()).length.equals(1);
      check(find.text('item 9').evaluate()).length.equals(1);
      // The duplicated ids still collapse to one row each.
      check(find.text('item 0').evaluate()).length.equals(1);
      check(find.text('item 4').evaluate()).length.equals(1);
    });

    scenarioWidgets('de-dup by id collapses a search overlap across a page boundary to one', (
      tester,
    ) async {
      await _pumpPagedSearch(
        tester,
        searchFetchPage: overlappingSearchPages,
        itemIdGetter: (item) => item.id,
      );
      await drain(tester, frames: 8);

      // Same collapse as the normal path, proving de-dup covers the search branch of the fetch.
      check(find.text('item 3').evaluate()).length.equals(1);
      check(find.text('item 4').evaluate()).length.equals(1);
      check(find.text('item 0').evaluate()).length.equals(1);
      check(find.text('item 7').evaluate()).length.equals(1);
    });
  });
}

/// No `==` override, so 2 `_Item`s with the same [id] are different objects, like a refetch that
/// returns the same data as new instances.
class _Item(final int id);

Future<void> _pumpPagedList(
  WidgetTester tester, {
  required PageFetcher<_Item> fetchPage,
  required ItemIdGetter<_Item> itemIdGetter,
}) => pumpListSmith(
  tester,
  ListSmith.async(
    fetchPage: fetchPage,
    itemIdGetter: itemIdGetter,
    pageSize: 5,
    refresh: const NoRefresh(),
    itemBuilder: (_, item, _) => Text('item ${item.id}'),
  ),
);

/// Pumps a search list driven by [searchFetchPage] under a seeded, non-empty query, so the 1st fetch
/// runs in search mode. The normal [PageFetcher] is never reached, so it is a stub.
Future<void> _pumpPagedSearch(
  WidgetTester tester, {
  required SearchPageFetcher<_Item> searchFetchPage,
  required ItemIdGetter<_Item> itemIdGetter,
}) => pumpListSmith(
  tester,
  ListSmith.async(
    fetchPage: PageFetcher((_) async => const <_Item>[]),
    search: AsyncSearch(fetchPage: searchFetchPage),
    itemIdGetter: itemIdGetter,
    pageSize: 5,
    refresh: const NoRefresh(),
    query: 'q',
    searchDebounce: const Duration(milliseconds: 20),
    itemBuilder: (_, item, _) => Text('item ${item.id}'),
  ),
);

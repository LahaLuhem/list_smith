// `_Item` is a private test fixture (a reference-identity type with no `==`), not this file's
// subject, so its name intentionally differs from the filename.
// ignore_for_file: prefer-match-file-name

import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

import '../support/support.dart';

void main() {
  feature('ListSmith.async pagination dedup', () {
    // Overlapping pages: page 0 ends with ids 3, 4 and page 1 begins with FRESH `_Item(3)`,
    // `_Item(4)` (the shape an offset-based backend produces when its data shifts between fetches).
    // ISP appends pages verbatim and never dedups, so ids 3 and 4 land in the list twice. They are
    // different objects with no `==`, so only an id-based dedup key can collapse them.
    final overlappingPages = pagedFetcher([
      [_Item(0), _Item(1), _Item(2), _Item(3), _Item(4)],
      [_Item(3), _Item(4), _Item(5), _Item(6), _Item(7)],
    ]);

    // A mid-stream page that is ENTIRELY page 0's ids (fresh objects), followed by a genuinely new
    // page. De-dup collapses page 1 to nothing for display; the end policy must still see that the
    // backend returned a full page there, or it reads the empty result as end-of-data and never
    // fetches page 2. Page 3 is empty, the real end.
    final allDuplicateMidStreamPages = pagedFetcher([
      [_Item(0), _Item(1), _Item(2), _Item(3), _Item(4)],
      [_Item(0), _Item(1), _Item(2), _Item(3), _Item(4)],
      [_Item(5), _Item(6), _Item(7), _Item(8), _Item(9)],
    ]);

    // The same overlap as [overlappingPages], but served through `searchFetchPage`. De-dup runs on
    // the shared fetch path, so it must behave identically under an active query.
    final overlappingSearchPages = pagedSearchFetcher([
      [_Item(0), _Item(1), _Item(2), _Item(3), _Item(4)],
      [_Item(3), _Item(4), _Item(5), _Item(6), _Item(7)],
    ]);

    scenarioWidgets('an itemId key collapses an item repeated across a page boundary to one', (
      tester,
    ) async {
      await _pumpPagedList(tester, fetchPage: overlappingPages, itemId: (item) => item.id);
      await drain(tester, frames: 8);

      // Ids 3 and 4 are returned by BOTH page 0 and page 1; the key collapses each to one.
      check(find.text('item 3').evaluate()).length.equals(1);
      check(find.text('item 4').evaluate()).length.equals(1);
      // Non-overlapping ids are unaffected controls.
      check(find.text('item 0').evaluate()).length.equals(1);
      check(find.text('item 7').evaluate()).length.equals(1);
    });

    scenarioWidgets('without an itemId, the overlap renders twice (de-dup is opt-in)', (
      tester,
    ) async {
      await _pumpPagedList(tester, fetchPage: overlappingPages);
      await drain(tester, frames: 8);

      // Default matches the underlying pager, which never de-duplicates: both copies show.
      check(find.text('item 3').evaluate()).length.equals(2);
      check(find.text('item 4').evaluate()).length.equals(2);
    });

    scenarioWidgets('an all-duplicate mid-stream page does not end pagination before later pages', (
      tester,
    ) async {
      await _pumpPagedList(
        tester,
        fetchPage: allDuplicateMidStreamPages,
        itemId: (item) => item.id,
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

    scenarioWidgets('an itemId key collapses a search overlap across a page boundary to one', (
      tester,
    ) async {
      await _pumpPagedSearch(
        tester,
        searchFetchPage: overlappingSearchPages,
        itemId: (item) => item.id,
      );
      await drain(tester, frames: 8);

      // Same collapse as the normal path, proving de-dup covers the search branch of the fetch.
      check(find.text('item 3').evaluate()).length.equals(1);
      check(find.text('item 4').evaluate()).length.equals(1);
      check(find.text('item 0').evaluate()).length.equals(1);
      check(find.text('item 7').evaluate()).length.equals(1);
    });

    scenarioWidgets('without an itemId, a search overlap renders twice', (tester) async {
      await _pumpPagedSearch(tester, searchFetchPage: overlappingSearchPages);
      await drain(tester, frames: 8);

      // De-dup is opt-in on the search path too: both copies show.
      check(find.text('item 3').evaluate()).length.equals(2);
      check(find.text('item 4').evaluate()).length.equals(2);
    });
  });
}

/// A reference-identity item: two `_Item`s with the same [id] are DIFFERENT objects (no `==`
/// override), modelling a refetch that returns the same data as new instances.
class _Item {
  _Item(this.id);

  final int id;
}

Future<void> _pumpPagedList(
  WidgetTester tester, {
  required PageFetcher<_Item> fetchPage,
  ItemId<_Item>? itemId,
}) => pumpListSmith(
  tester,
  ListSmith.async(
    fetchPage: fetchPage,
    itemId: itemId,
    pageSize: 5,
    pullToRefresh: false,
    itemBuilder: (_, item, _) => Text('item ${item.id}'),
  ),
);

/// Pumps a search list driven by [searchFetchPage] under a seeded, non-empty query, so the first
/// fetch runs in search mode. The normal [PageFetcher] is never reached, so it is a stub.
Future<void> _pumpPagedSearch(
  WidgetTester tester, {
  required SearchPageFetcher<_Item> searchFetchPage,
  ItemId<_Item>? itemId,
}) => pumpListSmith(
  tester,
  ListSmith.async(
    fetchPage: PageFetcher((_, _) async => const <_Item>[]),
    searchFetchPage: searchFetchPage,
    itemId: itemId,
    pageSize: 5,
    pullToRefresh: false,
    query: 'q',
    searchDebounce: const Duration(milliseconds: 20),
    itemBuilder: (_, item, _) => Text('item ${item.id}'),
  ),
);

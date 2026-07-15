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
    final overlappingPages = pagedFetcher<_Item>([
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

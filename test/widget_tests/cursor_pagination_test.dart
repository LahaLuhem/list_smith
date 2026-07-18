import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

import '../support/support.dart';

void main() {
  feature('ListSmith.async cursor pagination', () {
    scenarioWidgets('drives each fetch with the previous page cursor and stops on a null cursor', (
      tester,
    ) async {
      final received = <Object?>[];
      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: _cursorFetcher(received),
          endPolicy: const StopOnNullSignalPolicy(),
          refresh: const NoRefresh(),
          itemBuilder: (_, item, _) => Text('item $item'),
        ),
      );
      await drain(tester, frames: 12);

      // All three cursor-chained pages loaded; each fetch received the prior page's cursor, and the
      // null cursor on the last page ended pagination without a trailing fetch.
      check(find.text('item 1').evaluate()).length.equals(1);
      check(find.text('item 9').evaluate()).length.equals(1);
      check(received).deepEquals(const [null, 'c1', 'c2']);
      check(find.text('No more items').evaluate()).length.equals(1);
    });

    scenarioWidgets('pull-to-refresh restarts from the initial (null) cursor', (tester) async {
      final received = <Object?>[];
      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: _cursorFetcher(received),
          endPolicy: const StopOnNullSignalPolicy(),
          itemBuilder: (_, item, _) => Text('item $item'),
        ),
      );
      await drain(tester, frames: 12);
      received.clear();

      await tester.fling(find.text('item 1'), const Offset(0, 300), 1000);
      for (var frame = 0; frame < 6; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await drain(tester, frames: 12);

      // Refresh discarded the cursor, so the reload started again from a null cursor.
      check(received.first).isNull();
      check(find.text('item 1').evaluate()).length.equals(1);
    });

    scenarioWidgets('cursor search drives the search stream from its own cursor', (tester) async {
      final received = <Object?>[];
      final searchFetchPage = SearchPageFetcher<int>.withSignal((_, _, _, previousCursor) async {
        received.add(previousCursor);

        return switch (previousCursor) {
          null => (const [10, 11], 's1'),
          's1' => (const [12, 13], null),
          _ => (const <int>[], null),
        };
      });

      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: PageFetcher.withSignal((_, _, _) async => (const [1, 2, 3], null)),
          search: AsyncSearch(fetchPage: searchFetchPage),
          endPolicy: const StopOnNullSignalPolicy(),
          query: 'q',
          searchDebounce: const Duration(milliseconds: 20),
          refresh: const NoRefresh(),
          itemBuilder: (_, item, _) => Text('item $item'),
        ),
      );
      await settle(tester);
      await drain(tester, frames: 12);

      // Both search pages loaded via the cursor chain, then the null cursor ended it.
      check(find.text('item 10').evaluate()).length.equals(1);
      check(find.text('item 13').evaluate()).length.equals(1);
      check(received).deepEquals(const [null, 's1']);
    });
  });
}

/// A fake cursor-paged backend: three pages chained by opaque string cursors, then a `null` cursor
/// that ends it. It dispatches on the `previousCursor` it is handed, not the page index, so it proves
/// the cursor drives the fetch; [received] records each cursor the fetcher saw.
PageFetcher<int> _cursorFetcher(List<Object?> received) =>
    PageFetcher<int>.withSignal((_, _, previousCursor) async {
      received.add(previousCursor);

      return switch (previousCursor) {
        null => (const [1, 2, 3], 'c1'),
        'c1' => (const [4, 5, 6], 'c2'),
        'c2' => (const [7, 8, 9], null),
        _ => (const <int>[], null),
      };
    });

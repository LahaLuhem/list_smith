import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

import '../../../../support/support.dart';

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
          itemIdGetter: (item) => item,
          endPolicy: const StopOnNullSignalPolicy(),
          refresh: const NoRefresh(),
          itemBuilder: (_, item, _) => Text('item $item'),
        ),
      );
      await drain(tester, frames: 12);

      // All 3 cursor-chained pages loaded. Each fetch received the prior page's cursor, and the null
      // cursor on the last page ended pagination without a trailing fetch.
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
          itemIdGetter: (item) => item,
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
      final searchFetchPage = SearchPageFetcher<int>.withSignal((request) async {
        received.add(request.previousSignal);

        return switch (request.previousSignal) {
          null => (const [10, 11], 's1'),
          's1' => (const [12, 13], null),
          _ => (const <int>[], null),
        };
      });

      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: PageFetcher.withSignal((_) async => (const [1, 2, 3], null)),
          itemIdGetter: (item) => item,
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

  feature('ListSmith.async hasMore pagination', () {
    scenarioWidgets('ends once a page says hasMore is false, without asking for another page', (
      tester,
    ) async {
      final server = FakeServer(List.generate(6, (index) => index));
      await _pumpPaged(tester, server.hasMoreFetcher);

      check(server.requests.map((request) => request.pageIndex)).deepEquals([0, 1]);
      check(find.text('No more items').evaluate()).length.equals(1);
    });

    scenarioWidgets('its fetches get no previousSignal, since they page by number', (tester) async {
      final server = FakeServer(List.generate(9, (index) => index));
      await _pumpPaged(tester, server.hasMoreFetcher);

      check(server.requests).length.equals(3);
      check(server.requests.map((request) => request.previousSignal)).every((it) => it.isNull());
    });

    scenarioWidgets('the end policy can still end it first', (tester) async {
      final server = FakeServer(List.generate(9, (index) => index));
      await _pumpPaged(
        tester,
        server.hasMoreFetcher,
        endPolicy: const FixedPageCountPolicy(pageCount: 1),
      );

      check(server.requests.map((request) => request.pageIndex)).deepEquals([0]);
      check(find.text('No more items').evaluate()).length.equals(1);
    });

    scenarioWidgets('search ends on its own hasMore flag', (tester) async {
      final searchPageIndexes = <int>[];
      final searchFetchPage = SearchPageFetcher<int>.withHasMore((request) async {
        searchPageIndexes.add(request.pageIndex);

        return (const [99], hasMore: false);
      });

      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: PageFetcher((_) async => const [1, 2, 3]),
          itemIdGetter: (item) => item,
          search: AsyncSearch(fetchPage: searchFetchPage),
          query: 'q',
          searchDebounce: const Duration(milliseconds: 20),
          refresh: const NoRefresh(),
          itemBuilder: (_, item, _) => Text('item $item'),
        ),
      );
      await settle(tester);

      check(searchPageIndexes).deepEquals([0]);
      check(find.text('No more items').evaluate()).length.equals(1);
    });
  });
}

/// Pumps a list of 3 a page over [fetchPage] and lets it load.
Future<void> _pumpPaged(
  WidgetTester tester,
  PageFetcher<int> fetchPage, {
  PaginationEndPolicy endPolicy = const StopOnEmptyPagesPolicy(),
}) async {
  await pumpListSmith(
    tester,
    ListSmith.async(
      fetchPage: fetchPage,
      pageSize: 3,
      itemIdGetter: (item) => item,
      endPolicy: endPolicy,
      refresh: const NoRefresh(),
      itemBuilder: (_, item, _) => Text('item $item'),
    ),
  );
  await drain(tester, frames: 12);
}

/// A fake cursor-paged backend: 3 pages chained by opaque string cursors, then a `null` cursor that
/// ends it. It dispatches on the request's `previousSignal`, not its page index, so it proves the cursor
/// drives the fetch. [received] records each cursor the fetcher saw.
PageFetcher<int> _cursorFetcher(List<Object?> received) =>
    PageFetcher<int>.withSignal((request) async {
      received.add(request.previousSignal);

      return switch (request.previousSignal) {
        null => (const [1, 2, 3], 'c1'),
        'c1' => (const [4, 5, 6], 'c2'),
        'c2' => (const [7, 8, 9], null),
        _ => (const <int>[], null),
      };
    });

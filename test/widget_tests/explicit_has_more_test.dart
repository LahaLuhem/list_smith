import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

import '../support/support.dart';

void main() {
  feature('ListSmith.async ExplicitHasMorePolicy', () {
    scenarioWidgets('asserts when paired with a plain (non-signal) fetcher', (tester) async {
      expect(
        () => ListSmith.async(
          fetchPage: PageFetcher((_, _) async => const <int>[]),
          endPolicy: const ExplicitHasMorePolicy(),
          itemBuilder: (_, item, _) => Text('item $item'),
        ),
        throwsAssertionError,
      );
    });

    scenarioWidgets('stops on hasMore=false without fetching the trailing empty page', (
      tester,
    ) async {
      final requested = <int>[];
      const dataPages = [
        [1, 2, 3],
        [4, 5, 6],
      ];
      final fetchPage = PageFetcher<int>.withSignal((pageIndex, _) async {
        requested.add(pageIndex);
        final items = pageIndex < dataPages.length ? dataPages[pageIndex] : const <int>[];

        return (items, pageIndex < dataPages.length - 1);
      });

      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: fetchPage,
          endPolicy: const ExplicitHasMorePolicy(),
          refresh: const NoRefresh(),
          itemBuilder: (_, item, _) => Text('item $item'),
        ),
      );
      await drain(tester, frames: 8);

      // Page 1 reported hasMore=false, so pagination ends there: the empty index 2 is never requested.
      check(find.text('item 6').evaluate()).length.equals(1);
      check(requested).deepEquals(const [0, 1]);
    });

    scenarioWidgets('shows the no-more footer once the fetcher reports the end', (tester) async {
      final fetchPage = PageFetcher<int>.withSignal(
        (pageIndex, _) async => pageIndex == 0 ? (const [1, 2, 3], false) : (const <int>[], false),
      );

      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: fetchPage,
          endPolicy: const ExplicitHasMorePolicy(),
          refresh: const NoRefresh(),
          itemBuilder: (_, item, _) => Text('item $item'),
        ),
      );
      await drain(tester, frames: 8);

      check(find.text('No more items').evaluate()).length.equals(1);
    });

    scenarioWidgets('the signal governs the search stream too', (tester) async {
      final fetchPage = PageFetcher<int>.withSignal((_, _) async => (const [1, 2, 3], true));
      final searchFetchPage = SearchPageFetcher<int>.withSignal(
        (_, pageIndex, _) async => pageIndex == 0 ? (const [99], false) : (const <int>[], false),
      );

      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: fetchPage,
          search: AsyncSearch(fetchPage: searchFetchPage),
          endPolicy: const ExplicitHasMorePolicy(),
          query: 'q',
          searchDebounce: const Duration(milliseconds: 20),
          refresh: const NoRefresh(),
          itemBuilder: (_, item, _) => Text('item $item'),
        ),
      );
      await settle(tester);

      // Search page 0 reported hasMore=false via SearchPageFetcher.withSignal: results show, then end.
      check(find.text('item 99').evaluate()).length.equals(1);
      check(find.text('No more items').evaluate()).length.equals(1);
    });

    scenarioWidgets('KeepCachePolicy restores the normal list after an ExplicitHasMore search', (
      tester,
    ) async {
      final fetchPage = PageFetcher<int>.withSignal(
        (pageIndex, _) async => pageIndex == 0 ? (const [1, 2, 3], false) : (const <int>[], false),
      );
      final searchFetchPage = SearchPageFetcher<int>.withSignal(
        (_, pageIndex, _) async => pageIndex == 0 ? (const [99], false) : (const <int>[], false),
      );

      Widget build(String query) => ListSmith.async(
        fetchPage: fetchPage,
        search: AsyncSearch(fetchPage: searchFetchPage, cachePolicy: const KeepCachePolicy()),
        endPolicy: const ExplicitHasMorePolicy(),
        query: query,
        searchDebounce: const Duration(milliseconds: 20),
        refresh: const NoRefresh(),
        itemBuilder: (_, item, _) => Text('item $item'),
      );

      await pumpListSmith(tester, build(''));
      await settle(tester);
      check(find.text('item 1').evaluate()).length.equals(1);

      await pumpListSmith(tester, build('x'));
      await settle(tester);
      check(find.text('item 99').evaluate()).length.equals(1);
      check(find.text('item 1').evaluate()).length.equals(0);

      await pumpListSmith(tester, build(''));
      await settle(tester);

      // Normal list restored (KeepCache) after a search that ended via the signal.
      check(find.text('item 1').evaluate()).length.equals(1);
      check(find.text('item 99').evaluate()).length.equals(0);
    });

    scenarioWidgets('pull-to-refresh re-enables pagination after the end', (tester) async {
      var firstPageFetches = 0;
      final fetchPage = PageFetcher<int>.withSignal((pageIndex, _) async {
        if (pageIndex == 0) firstPageFetches++;

        return pageIndex == 0 ? (const [1, 2, 3], false) : (const <int>[], false);
      });

      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: fetchPage,
          endPolicy: const ExplicitHasMorePolicy(),
          itemBuilder: (_, item, _) => Text('item $item'),
        ),
      );
      await drain(tester, frames: 8);
      check(firstPageFetches).equals(1);

      await tester.fling(find.text('item 1'), const Offset(0, 300), 1000);
      for (var frame = 0; frame < 6; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await drain(tester, frames: 4);

      // Refresh reset the ended state and re-fetched page 0.
      check(firstPageFetches).equals(2);
      check(find.text('item 1').evaluate()).length.equals(1);
    });
  });
}

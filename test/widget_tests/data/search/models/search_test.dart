import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

import '../../../../support/support.dart';

void main() {
  feature('ListSmith.async search', () {
    scenarioWidgets('an empty query shows the normal list even with a search fetcher', (
      tester,
    ) async {
      await _pumpAsyncSearch(
        tester,
        fetchPage: PageFetcher(
          (request) async => request.pageIndex == 0 ? const [1, 2, 3] : const <int>[],
        ),
        searchFetchPage: SearchPageFetcher((_) async => const [99]),
        query: '',
      );
      await settle(tester);

      check(find.text('item 1').evaluate()).length.equals(1);
      check(find.text('item 99').evaluate()).length.equals(0);
    });

    scenarioWidgets('a non-empty query shows the search results', (tester) async {
      await _pumpAsyncSearch(
        tester,
        fetchPage: PageFetcher((_) async => const [1, 2, 3]),
        searchFetchPage: SearchPageFetcher(
          (request) async => request.pageIndex == 0 ? [request.query.length * 10] : const <int>[],
        ),
        query: 'ab',
      );
      await settle(tester);

      check(find.text('item 20').evaluate()).length.equals(1);
      check(find.text('item 1').evaluate()).length.equals(0);
    });

    scenarioWidgets('a search that matches nothing shows the no-results surface', (tester) async {
      await _pumpAsyncSearch(
        tester,
        fetchPage: PageFetcher((_) async => const [1, 2, 3]),
        searchFetchPage: SearchPageFetcher((_) async => const <int>[]),
        query: 'zzz',
      );
      await settle(tester);

      check(find.text('No results').evaluate()).length.equals(1);
    });

    scenarioWidgets('KeepCachePolicy restores the normal list on clearing, without refetching', (
      tester,
    ) async {
      var normalFetches = 0;
      final fetchPage = PageFetcher<int>((request) async {
        normalFetches++;

        return request.pageIndex == 0 ? const [1, 2, 3] : const <int>[];
      });

      final searchFetchPage = SearchPageFetcher<int>(
        (request) async => request.pageIndex == 0 ? const [99] : const <int>[],
      );

      await _pumpAsyncSearch(
        tester,
        fetchPage: fetchPage,
        searchFetchPage: searchFetchPage,
        query: '',
        cachePolicy: const KeepCachePolicy(),
      );
      await settle(tester);
      check(find.text('item 1').evaluate()).length.equals(1);
      final fetchesAfterNormal = normalFetches;

      await _pumpAsyncSearch(
        tester,
        fetchPage: fetchPage,
        searchFetchPage: searchFetchPage,
        query: 'x',
        cachePolicy: const KeepCachePolicy(),
      );
      await settle(tester);
      check(find.text('item 99').evaluate()).length.equals(1);

      await _pumpAsyncSearch(
        tester,
        fetchPage: fetchPage,
        searchFetchPage: searchFetchPage,
        query: '',
        cachePolicy: const KeepCachePolicy(),
      );
      await settle(tester);
      check(find.text('item 1').evaluate()).length.equals(1);
      check(normalFetches).equals(fetchesAfterNormal);
    });

    scenarioWidgets('ReplaceCachePolicy refetches the normal list on clearing', (tester) async {
      var normalFetches = 0;
      final fetchPage = PageFetcher<int>((request) async {
        normalFetches++;

        return request.pageIndex == 0 ? const [1, 2, 3] : const <int>[];
      });

      final searchFetchPage = SearchPageFetcher<int>(
        (request) async => request.pageIndex == 0 ? const [99] : const <int>[],
      );

      await _pumpAsyncSearch(
        tester,
        fetchPage: fetchPage,
        searchFetchPage: searchFetchPage,
        query: '',
      );
      await settle(tester);
      final fetchesAfterNormal = normalFetches;

      await _pumpAsyncSearch(
        tester,
        fetchPage: fetchPage,
        searchFetchPage: searchFetchPage,
        query: 'x',
      );
      await settle(tester);
      check(find.text('item 99').evaluate()).length.equals(1);

      await _pumpAsyncSearch(
        tester,
        fetchPage: fetchPage,
        searchFetchPage: searchFetchPage,
        query: '',
      );
      await settle(tester);
      check(find.text('item 1').evaluate()).length.equals(1);
      check(normalFetches).isGreaterThan(fetchesAfterNormal);
    });

    scenarioWidgets('taking search away mid-search brings back a fresh feed', (tester) async {
      var feedFetches = 0;
      Widget build({required Search<int> search, required String query}) => ListSmith.async(
        fetchPage: PageFetcher((request) async {
          if (request.pageIndex == 0) feedFetches++;

          return request.pageIndex == 0 ? const [1, 2, 3] : const <int>[];
        }),
        itemIdGetter: (item) => item,
        search: search,
        query: query,
        searchDebounce: const Duration(milliseconds: 20),
        itemBuilder: (_, item, _) => Text('item $item'),
      );

      await pumpListSmith(
        tester,
        build(
          search: AsyncSearch(fetchPage: SearchPageFetcher((_) async => const [99])),
          query: 'ab',
        ),
      );
      await settle(tester);
      // Premise: searching from the start, so the feed hasn't loaded yet.
      check(find.text('item 99').evaluate()).length.equals(1);
      check(feedFetches).equals(0);

      await pumpListSmith(tester, build(search: const NoSearch(), query: ''));
      await settle(tester);

      check(find.text('item 1').evaluate()).length.equals(1);
      check(find.text('item 99').evaluate()).isEmpty();
      check(feedFetches).equals(1);
    });

    scenarioWidgets('taking search away under KeepCachePolicy lands back on the kept feed', (
      tester,
    ) async {
      var feedFetches = 0;
      Widget build({required Search<int> search, required String query}) => ListSmith.async(
        fetchPage: PageFetcher((request) async {
          if (request.pageIndex == 0) feedFetches++;

          return request.pageIndex == 0 ? const [1, 2, 3] : const <int>[];
        }),
        itemIdGetter: (item) => item,
        search: search,
        query: query,
        searchDebounce: const Duration(milliseconds: 20),
        itemBuilder: (_, item, _) => Text('item $item'),
      );
      final keepingSearch = AsyncSearch<int>(
        fetchPage: SearchPageFetcher((_) async => const [99]),
        cachePolicy: const KeepCachePolicy(),
      );

      await pumpListSmith(tester, build(search: keepingSearch, query: ''));
      await settle(tester);
      await pumpListSmith(tester, build(search: keepingSearch, query: 'ab'));
      await settle(tester);
      // Premise: searching, with the feed loaded once and kept.
      check(find.text('item 99').evaluate()).length.equals(1);
      check(feedFetches).equals(1);

      await pumpListSmith(tester, build(search: const NoSearch(), query: ''));
      await settle(tester);

      check(find.text('item 1').evaluate()).length.equals(1);
      check(feedFetches).equals(1);
    });
  });
}

Future<void> _pumpAsyncSearch(
  WidgetTester tester, {
  required PageFetcher<int> fetchPage,
  required SearchPageFetcher<int> searchFetchPage,
  required String query,
  SearchCachePolicy cachePolicy = const ReplaceCachePolicy(),
}) => pumpListSmith(
  tester,
  ListSmith.async(
    fetchPage: fetchPage,
    itemIdGetter: (item) => item,
    search: AsyncSearch(fetchPage: searchFetchPage, cachePolicy: cachePolicy),
    query: query,
    searchDebounce: const Duration(milliseconds: 20),
    itemBuilder: (_, item, _) => Text('item $item'),
  ),
);

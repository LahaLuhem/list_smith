import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

import '../support/bdd.dart';

void main() {
  feature('ListSmith.async surfaces', () {
    scenarioOutlineWidgets<({PageFetcher<int> fetchPage, String shows})>(
      'renders the right surface for the source state',
      examples: {
        'the first page of items': (
          fetchPage: (pageIndex, _) async => pageIndex == 0 ? const [1, 2, 3] : const <int>[],
          shows: 'item 1',
        ),
        'the empty surface when the source has no items': (
          fetchPage: (_, _) async => const <int>[],
          shows: 'No items',
        ),
        'the no-more footer once every page has loaded': (
          fetchPage: (pageIndex, _) async => pageIndex == 0 ? const [1, 2, 3] : const <int>[],
          shows: 'No more items',
        ),
      },
      outline: (tester, example) async {
        await _pumpList(tester, example.fetchPage);
        await _drainPages(tester);

        check(find.text(example.shows).evaluate()).length.equals(1);
      },
    );

    scenarioWidgets('shows the error surface, then retry recovers to the items', (tester) async {
      var calls = 0;
      await _pumpList(tester, (pageIndex, _) async {
        calls++;
        if (calls == 1) throw Exception('network');

        return pageIndex == 0 ? const [1, 2, 3] : const <int>[];
      });
      await _drainPages(tester);

      check(find.text('Something went wrong').evaluate()).length.equals(1);
      check(find.text('Retry').evaluate()).length.equals(1);

      await tester.tap(find.text('Retry'));
      await _drainPages(tester);

      check(find.text('item 1').evaluate()).length.equals(1);
    });
  });

  feature('ListSmith.sync surfaces', () {
    bool contains(String item, String query) => item.toLowerCase().contains(query.toLowerCase());

    scenarioWidgets('shows all items when there is no query', (tester) async {
      await _pumpSyncList(tester, items: const ['apple', 'banana'], searchBy: contains);
      await tester.pump();

      check(find.text('apple').evaluate()).length.equals(1);
      check(find.text('banana').evaluate()).length.equals(1);
    });

    scenarioWidgets('shows the empty surface when there are no items', (tester) async {
      await _pumpSyncList(tester, items: const <String>[], searchBy: contains);
      await tester.pump();

      check(find.text('No items').evaluate()).length.equals(1);
    });

    scenarioWidgets('filters to the matches when a query is set', (tester) async {
      await _pumpSyncList(
        tester,
        items: const ['apple', 'banana'],
        searchBy: contains,
        query: 'app',
      );
      await tester.pump();

      check(find.text('apple').evaluate()).length.equals(1);
      check(find.text('banana').evaluate()).length.equals(0);
    });

    scenarioWidgets('shows the no-results surface when a query matches nothing', (tester) async {
      await _pumpSyncList(
        tester,
        items: const ['apple', 'banana'],
        searchBy: contains,
        query: 'xyz',
      );
      await tester.pump();

      check(find.text('No results').evaluate()).length.equals(1);
    });
  });

  feature('ListSmith.async search', () {
    scenarioWidgets('an empty query shows the normal list even with a search fetcher', (
      tester,
    ) async {
      await _pumpAsyncSearch(
        tester,
        fetchPage: (pageIndex, _) async => pageIndex == 0 ? const [1, 2, 3] : const <int>[],
        searchFetchPage: (_, _, _) async => const [99],
        query: '',
      );
      await _settle(tester);

      check(find.text('item 1').evaluate()).length.equals(1);
      check(find.text('item 99').evaluate()).length.equals(0);
    });

    scenarioWidgets('a non-empty query shows the search results', (tester) async {
      await _pumpAsyncSearch(
        tester,
        fetchPage: (_, _) async => const [1, 2, 3],
        searchFetchPage: (query, pageIndex, _) async =>
            pageIndex == 0 ? [query.length * 10] : const <int>[],
        query: 'ab',
      );
      await _settle(tester);

      check(find.text('item 20').evaluate()).length.equals(1);
      check(find.text('item 1').evaluate()).length.equals(0);
    });

    scenarioWidgets('a search that matches nothing shows the no-results surface', (tester) async {
      await _pumpAsyncSearch(
        tester,
        fetchPage: (_, _) async => const [1, 2, 3],
        searchFetchPage: (_, _, _) async => const <int>[],
        query: 'zzz',
      );
      await _settle(tester);

      check(find.text('No results').evaluate()).length.equals(1);
    });

    scenarioWidgets('KeepCachePolicy restores the normal list on clearing, without refetching', (
      tester,
    ) async {
      var normalFetches = 0;
      Future<Iterable<int>> fetchPage(int pageIndex, int _) async {
        normalFetches++;

        return pageIndex == 0 ? const [1, 2, 3] : const <int>[];
      }

      Future<Iterable<int>> searchFetchPage(String _, int pageIndex, int _) async =>
          pageIndex == 0 ? const [99] : const <int>[];

      await _pumpAsyncSearch(
        tester,
        fetchPage: fetchPage,
        searchFetchPage: searchFetchPage,
        query: '',
        cachePolicy: const KeepCachePolicy(),
      );
      await _settle(tester);
      check(find.text('item 1').evaluate()).length.equals(1);
      final fetchesAfterNormal = normalFetches;

      await _pumpAsyncSearch(
        tester,
        fetchPage: fetchPage,
        searchFetchPage: searchFetchPage,
        query: 'x',
        cachePolicy: const KeepCachePolicy(),
      );
      await _settle(tester);
      check(find.text('item 99').evaluate()).length.equals(1);

      await _pumpAsyncSearch(
        tester,
        fetchPage: fetchPage,
        searchFetchPage: searchFetchPage,
        query: '',
        cachePolicy: const KeepCachePolicy(),
      );
      await _settle(tester);
      check(find.text('item 1').evaluate()).length.equals(1);
      check(normalFetches).equals(fetchesAfterNormal);
    });

    scenarioWidgets('ReplaceCachePolicy refetches the normal list on clearing', (tester) async {
      var normalFetches = 0;
      Future<Iterable<int>> fetchPage(int pageIndex, int _) async {
        normalFetches++;

        return pageIndex == 0 ? const [1, 2, 3] : const <int>[];
      }

      Future<Iterable<int>> searchFetchPage(String _, int pageIndex, int _) async =>
          pageIndex == 0 ? const [99] : const <int>[];

      await _pumpAsyncSearch(
        tester,
        fetchPage: fetchPage,
        searchFetchPage: searchFetchPage,
        query: '',
      );
      await _settle(tester);
      final fetchesAfterNormal = normalFetches;

      await _pumpAsyncSearch(
        tester,
        fetchPage: fetchPage,
        searchFetchPage: searchFetchPage,
        query: 'x',
      );
      await _settle(tester);
      check(find.text('item 99').evaluate()).length.equals(1);

      await _pumpAsyncSearch(
        tester,
        fetchPage: fetchPage,
        searchFetchPage: searchFetchPage,
        query: '',
      );
      await _settle(tester);
      check(find.text('item 1').evaluate()).length.equals(1);
      check(normalFetches).isGreaterThan(fetchesAfterNormal);
    });
  });
}

Future<void> _pumpList(WidgetTester tester, PageFetcher<int> fetchPage) => tester.pumpWidget(
  Directionality(
    textDirection: .ltr,
    child: MediaQuery(
      data: const MediaQueryData(),
      child: ListSmith.async(fetchPage: fetchPage, itemBuilder: (_, item, _) => Text('item $item')),
    ),
  ),
);

/// Pumps a few frames so the post-frame first fetch, its async result, and any triggered next fetch
/// all settle. The neutral spinner animates forever, so we drive fixed pumps rather than `pumpAndSettle`.
Future<void> _drainPages(WidgetTester tester) async {
  for (var frame = 0; frame < 4; frame++) {
    await tester.pump();
  }
}

Future<void> _pumpSyncList(
  WidgetTester tester, {
  required List<String> items,
  required SyncSearchPredicate<String> searchBy,
  String query = '',
}) => tester.pumpWidget(
  Directionality(
    textDirection: .ltr,
    child: MediaQuery(
      data: const MediaQueryData(),
      child: ListSmith.sync(
        items: items,
        searchBy: searchBy,
        query: query,
        itemBuilder: (_, item, _) => Text(item),
      ),
    ),
  ),
);

Future<void> _pumpAsyncSearch(
  WidgetTester tester, {
  required PageFetcher<int> fetchPage,
  required SearchPageFetcher<int> searchFetchPage,
  required String query,
  SearchCachePolicy cachePolicy = const ReplaceCachePolicy(),
}) => tester.pumpWidget(
  Directionality(
    textDirection: .ltr,
    child: MediaQuery(
      data: const MediaQueryData(),
      child: ListSmith.async(
        fetchPage: fetchPage,
        searchFetchPage: searchFetchPage,
        query: query,
        searchCachePolicy: cachePolicy,
        searchDebounce: const Duration(milliseconds: 20),
        itemBuilder: (_, item, _) => Text('item $item'),
      ),
    ),
  ),
);

/// Fires the search debounce (20ms), then drains the triggered fetch.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 20));

  await _drainPages(tester);
}

import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

import '../../../support/support.dart';

void main() {
  feature('ListSmith.async search position', () {
    scenarioOutlineWidgets<({String fromQuery, double fromOffset, String toQuery, int topItem})>(
      'a committed query starts the list from the top',
      examples: const {
        'entering a search': (fromQuery: '', fromOffset: 1000, toQuery: '3', topItem: 3),
        // 1 and 2 match 14 items each, more than the screen holds.
        'changing it': (fromQuery: '1', fromOffset: 100, toQuery: '2', topItem: 2),
        'clearing it': (fromQuery: '3', fromOffset: 100, toQuery: '', topItem: 0),
      },
      outline: (tester, example) async {
        final queryNotifier = ValueNotifier(example.fromQuery);
        await _pumpSearch(tester, queryNotifier);
        await drain(tester);
        tester.state<ScrollableState>(listScrollableFinder).position.jumpTo(example.fromOffset);
        await tester.pump();

        await commitQuery(tester, queryNotifier, example.toQuery);

        check(tester.getTopLeft(find.text('item ${example.topItem}', skipOffstage: false)).dy)
            .equals(0);
      },
    );

    scenarioWidgets('a committed query that changes nothing keeps the place', (tester) async {
      final queryNotifier = ValueNotifier('');
      await _pumpSearch(tester, queryNotifier, minSearchLength: 2);
      await drain(tester);
      tester.state<ScrollableState>(listScrollableFinder).position.jumpTo(1000);
      await tester.pump();

      // Shorter than minSearchLength, so it counts as no search, like the empty query before it.
      await commitQuery(tester, queryNotifier, '3');

      check(tester.getTopLeft(find.text('item 20', skipOffstage: false)).dy).equals(0);
    });

    scenarioWidgets('clearing a search back to a kept feed starts from the top too', (
      tester,
    ) async {
      final queryNotifier = ValueNotifier('');
      await _pumpSearch(tester, queryNotifier, cachePolicy: const KeepCachePolicy());
      await drain(tester);
      tester.state<ScrollableState>(listScrollableFinder).position.jumpTo(1000);
      await tester.pump();
      await commitQuery(tester, queryNotifier, '3');
      tester.state<ScrollableState>(listScrollableFinder).position.jumpTo(100);
      await tester.pump();

      await commitQuery(tester, queryNotifier, '');

      check(tester.getTopLeft(find.text('item 0', skipOffstage: false)).dy).equals(0);
    });
  });
}

/// A `.async` list of `item 0` to `item 49` in 50 px rows, searched by [queryNotifier].
Future<void> _pumpSearch(
  WidgetTester tester,
  ValueNotifier<String> queryNotifier, {
  int minSearchLength = 0,
  SearchCachePolicy cachePolicy = const ReplaceCachePolicy(),
}) {
  final items = List.generate(50, (item) => item);
  final fetchPage = PageFetcher<int>(
    (request) async => request.pageIndex == 0 ? items : const <int>[],
  );
  final search = AsyncSearch<int>(
    fetchPage: SearchPageFetcher(
      (request) async => request.pageIndex == 0
          ? items.where((item) => '$item'.contains(request.query)).toList()
          : const <int>[],
    ),
    cachePolicy: cachePolicy,
  );

  return pumpListSmith(
    tester,
    ValueListenableBuilder(
      valueListenable: queryNotifier,
      builder: (_, query, _) => ListSmith<int>.async(
        fetchPage: fetchPage,
        itemIdGetter: (item) => item,
        search: search,
        query: query,
        minSearchLength: minSearchLength,
        searchDebounce: Duration.zero,
        itemBuilder: (_, item, _) => SizedBox(height: 50, child: Text('item $item')),
      ),
    ),
  );
}

import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

import '../../../../support/support.dart';

void main() {
  feature('ListSmith.async end policies reading the fetcher signal', () {
    scenarioOutlineWidgets<PaginationEndPolicy>(
      'a policy reading the end signal asserts over a plain fetcher',
      examples: const {
        'ExplicitHasMorePolicy': ExplicitHasMorePolicy(),
        'StopOnNullSignalPolicy': StopOnNullSignalPolicy(),
      },
      outline: (tester, endPolicy) async {
        check(
          () => ListSmith.async(
            fetchPage: PageFetcher((_) async => const <int>[]),
            itemIdGetter: (item) => item,
            endPolicy: endPolicy,
            itemBuilder: (_, item, _) => Text('item $item'),
          ),
        ).throws<AssertionError>();
      },
    );
  });

  feature('ListSmith.async ExplicitHasMorePolicy', () {
    scenarioWidgets('stops on hasMore=false without fetching the trailing empty page', (
      tester,
    ) async {
      final requested = <int>[];
      const dataPages = [
        [1, 2, 3],
        [4, 5, 6],
      ];
      final fetchPage = PageFetcher<int>.withSignal((request) async {
        requested.add(request.pageIndex);
        final items = request.pageIndex < dataPages.length
            ? dataPages[request.pageIndex]
            : const <int>[];

        return (items, request.pageIndex < dataPages.length - 1);
      });

      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: fetchPage,
          itemIdGetter: (item) => item,
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

    scenarioWidgets('the signal governs the search stream too', (tester) async {
      final searchPageIndexes = <int>[];
      final fetchPage = PageFetcher<int>.withSignal((_) async => (const [1, 2, 3], true));
      final searchFetchPage = SearchPageFetcher<int>.withSignal((request) async {
        searchPageIndexes.add(request.pageIndex);

        return request.pageIndex == 0 ? (const [99], false) : (const <int>[], false);
      });

      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: fetchPage,
          itemIdGetter: (item) => item,
          search: AsyncSearch(fetchPage: searchFetchPage),
          endPolicy: const ExplicitHasMorePolicy(),
          query: 'q',
          searchDebounce: const Duration(milliseconds: 20),
          refresh: const NoRefresh(),
          itemBuilder: (_, item, _) => Text('item $item'),
        ),
      );
      await settle(tester);

      // Search page 0 reported hasMore=false, so its page 1 is never asked for.
      check(searchPageIndexes).deepEquals(const [0]);
    });
  });
}

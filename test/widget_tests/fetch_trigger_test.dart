import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

import '../support/support.dart';

void main() {
  feature('ListSmith.async fetch triggers', () {
    scenarioWidgets('a cold list reports initialLoad, then nextPage as it pages', (tester) async {
      final triggers = <FetchTrigger>[];
      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: _recording(triggers, pages: 2),
          refresh: const NoRefresh(),
          itemBuilder: (_, item, _) => Text('item $item'),
        ),
      );
      await drain(tester, frames: 12);

      check(triggers.first).equals(.initialLoad);
      check(triggers.skip(1).toSet()).deepEquals(const {FetchTrigger.nextPage});
    });

    scenarioWidgets('a pull-to-refresh reports refresh, and the page after it does not', (
      tester,
    ) async {
      final triggers = <FetchTrigger>[];
      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: _recording(triggers, pages: 2),
          itemBuilder: (_, item, _) => Text('item $item'),
        ),
      );
      await drain(tester, frames: 12);
      triggers.clear();

      await tester.fling(find.text('item 0'), const Offset(0, 300), 1000);
      for (var frame = 0; frame < 6; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await drain(tester, frames: 12);

      // The reload's own page is refresh-driven; the pages it pages on to are not.
      check(triggers.first).equals(.refresh);
      check(triggers.skip(1).toSet()).deepEquals(const {FetchTrigger.nextPage});
    });

    scenarioWidgets('a controller refresh reports refresh, exactly as a pull does', (tester) async {
      final triggers = <FetchTrigger>[];
      final controller = ListSmithController();
      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: _recording(triggers, pages: 1),
          controller: controller,
          itemBuilder: (_, item, _) => Text('item $item'),
        ),
      );
      await drain(tester);
      triggers.clear();

      await controller.refresh();
      await drain(tester);

      check(triggers.first).equals(.refresh);
    });

    scenarioWidgets('a depth-keeping reload reports refresh for every page it re-fetches', (
      tester,
    ) async {
      final triggers = <FetchTrigger>[];
      final controller = ListSmithController();
      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: _recording(triggers, pages: 3),
          controller: controller,
          refresh: const PullToRefresh(reload: ReloadToCurrentDepth(concurrency: null)),
          itemBuilder: (_, item, _) => Text('item $item'),
        ),
      );
      await drain(tester, frames: 16);
      final depth = triggers.length;
      triggers.clear();

      await controller.refresh();
      await drain(tester, frames: 16);

      check(triggers.length).equals(depth);
      check(triggers.toSet()).deepEquals(const {FetchTrigger.refresh});
    });

    scenarioWidgets('retrying a failed page reports retry', (tester) async {
      final triggers = <FetchTrigger>[];
      var calls = 0;
      final fetchPage = PageFetcher<int>((request) async {
        triggers.add(request.trigger);
        if (calls++ == 0) throw Exception('network');

        return const [1, 2, 3];
      });

      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: fetchPage,
          refresh: const NoRefresh(),
          itemBuilder: (_, item, _) => Text('item $item'),
        ),
      );
      await drain(tester);
      check(triggers).deepEquals(const [FetchTrigger.initialLoad]);

      await tester.tap(find.text('Retry'));
      await drain(tester);

      check(triggers[1]).equals(.retry);
    });

    scenarioWidgets('a committed query change reports queryChanged on both fetchers', (
      tester,
    ) async {
      final normalTriggers = <FetchTrigger>[];
      final searchTriggers = <FetchTrigger>[];
      final searchFetchPage = SearchPageFetcher<int>((request) async {
        searchTriggers.add(request.trigger);

        return const [99];
      });

      Widget build(String query) => ListSmith.async(
        fetchPage: _recording(normalTriggers, pages: 1),
        search: AsyncSearch(fetchPage: searchFetchPage),
        query: query,
        searchDebounce: const Duration(milliseconds: 20),
        refresh: const NoRefresh(),
        itemBuilder: (_, item, _) => Text('item $item'),
      );

      await pumpListSmith(tester, build(''));
      await settle(tester);
      normalTriggers.clear();

      await pumpListSmith(tester, build('ab'));
      await settle(tester);
      check(searchTriggers.first).equals(.queryChanged);

      await pumpListSmith(tester, build(''));
      await settle(tester);

      // Leaving search reloads the normal list, which is the query changing too, not a refresh.
      check(normalTriggers.first).equals(.queryChanged);
    });
  });
}

/// A fetcher recording each request's [FetchTrigger] into [triggers], serving [pages] pages of three
/// items and then empty pages (the default end policy's end).
PageFetcher<int> _recording(List<FetchTrigger> triggers, {required int pages}) => PageFetcher<int>((
  request,
) async {
  triggers.add(request.trigger);
  final pageIndex = request.pageIndex;

  return pageIndex < pages ? [pageIndex * 3, pageIndex * 3 + 1, pageIndex * 3 + 2] : const <int>[];
});

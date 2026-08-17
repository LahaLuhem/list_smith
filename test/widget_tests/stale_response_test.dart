import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

import '../support/support.dart';

void main() {
  feature('ListSmith.async superseded fetches', () {
    scenarioWidgets('a superseded search page does not leak its cursor into the new query', (
      tester,
    ) async {
      final received = <({String query, Object? cursor})>[];
      final holds = {'a:1': Completer<void>(), 'ab:0': Completer<void>()};
      final searchFetchPage = SearchPageFetcher<int>.withSignal((request) async {
        final SearchPageRequest(:query, :pageIndex, :previousSignal) = request;

        received.add((query: query, cursor: previousSignal));
        await holds['$query:$pageIndex']?.future;

        return (const [1, 2, 3], '$query:$pageIndex');
      });

      await _pumpSearch(tester, searchFetchPage: searchFetchPage, query: 'a');
      await settle(tester);

      // Premise: page 1 of 'a' is in flight, holding page 0's cursor.
      check(received).deepEquals(const [(query: 'a', cursor: null), (query: 'a', cursor: 'a:0')]);

      await _pumpSearch(tester, searchFetchPage: searchFetchPage, query: 'ab');
      await settle(tester);

      // Land the fresh page, then the superseded one, with no frame between. The stale write only
      // does damage when it arrives last, so the order is forced rather than left to timing.
      holds['ab:0']!.complete();
      holds['a:1']!.complete();
      await tester.idle();
      await drain(tester);

      final leaked = received
          .where(
            (fetch) => fetch.cursor != null && !'${fetch.cursor}'.startsWith('${fetch.query}:'),
          )
          .toList();
      check(leaked).isEmpty();
    });

    scenarioWidgets('a superseded page does not fire onPageLoaded', (tester) async {
      var calls = 0;
      final hold = Completer<void>();
      // Holds the second fetch, page 1 of the pre-refresh stream, so it lands after the reload.
      final fetchPage = PageFetcher<int>((request) async {
        if (calls++ == 1) await hold.future;

        final pageIndex = request.pageIndex;

        return pageIndex < 2 ? [pageIndex * 3 + 1, pageIndex * 3 + 2] : const <int>[];
      });
      final observer = RecordingListSmithObserver();
      final controller = ListSmithController();

      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: fetchPage,
          controller: controller,
          observer: observer,
          itemBuilder: (_, item, _) => Text('item $item'),
        ),
      );
      await drain(tester);

      await controller.refresh();
      await drain(tester, frames: 12);

      hold.complete();
      await tester.idle();
      await drain(tester);

      // The reload's own page 1 is the only one the list kept, so the dropped one stays silent.
      final pageOneLoads = observer.events.where(
        (event) => event.startsWith('pageLoaded(index: 1,'),
      );
      check(pageOneLoads.toList()).length.equals(1);
    });

    scenarioWidgets('a page superseded by a depth-reload commit stays silent', (tester) async {
      final hold = Completer<void>();
      final observer = RecordingListSmithObserver();
      final controller = ListSmithController();
      // Page 2 is fetched once, while pages 0 and 1 are already in, so holding it by index is enough:
      // the reload only re-fetches the pages that landed.
      final fetchPage = PageFetcher<int>((request) async {
        final pageIndex = request.pageIndex;
        if (pageIndex == 2) await hold.future;

        return [pageIndex * 3, pageIndex * 3 + 1, pageIndex * 3 + 2];
      });

      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: fetchPage,
          controller: controller,
          observer: observer,
          refresh: const PullToRefresh(reload: ReloadToCurrentDepth()),
          itemBuilder: (_, item, _) => Text('item $item'),
        ),
      );
      await drain(tester, frames: 12);

      // Premise: pages 0 and 1 are in and page 2 is in flight, so the reload's depth is 2.
      check(observer.events.where((event) => event.startsWith('pageLoaded')).toList()).length
          .equals(2);

      await controller.refresh();
      await drain(tester, frames: 16);

      hold.complete();
      await tester.idle();
      await drain(tester);

      // commit() bumped the generation, so page 2's late arrival announces nothing. Its *items* still
      // land on top of the commit; that half is #36, and this guard is not a fix for it.
      check(observer.events.where((event) => event.startsWith('pageLoaded(index: 2,'))).isEmpty();
    });

    scenarioWidgets('a search page superseded by a KeepCache restore stays silent', (tester) async {
      final hold = Completer<void>();
      final observer = RecordingListSmithObserver();
      final searchFetchPage = SearchPageFetcher<int>((request) async {
        await hold.future;

        return const [99];
      });

      Widget build(String query) => ListSmith.async(
        fetchPage: PageFetcher(
          (request) async => [request.pageIndex * 3, request.pageIndex * 3 + 1],
        ),
        search: AsyncSearch(fetchPage: searchFetchPage, cachePolicy: const KeepCachePolicy()),
        query: query,
        searchDebounce: const Duration(milliseconds: 20),
        refresh: const NoRefresh(),
        observer: observer,
        itemBuilder: (_, item, _) => Text('item $item'),
      );

      await pumpListSmith(tester, build(''));
      await settle(tester);

      // Enter search: the normal list is snapshotted and the search's first page is left in flight.
      await pumpListSmith(tester, build('x'));
      await settle(tester);

      // Leave search again, restoring the snapshot while that search page is still out there.
      await pumpListSmith(tester, build(''));
      await settle(tester);

      hold.complete();
      await tester.idle();
      await drain(tester);

      // The restore bumped the generation, so the abandoned search page announces nothing.
      check(observer.events.where((event) => event.contains('search: true'))).isEmpty();
    });
  });
}

/// Pumps a cursor-driven async search list over [searchFetchPage] for [query]. The normal fetcher is
/// never reached (the query is always non-empty), and refresh is off so only the query drives resets.
Future<void> _pumpSearch(
  WidgetTester tester, {
  required SearchPageFetcher<int> searchFetchPage,
  required String query,
}) => pumpListSmith(
  tester,
  ListSmith.async(
    fetchPage: PageFetcher.withSignal((_) async => (const [0], null)),
    search: AsyncSearch(fetchPage: searchFetchPage),
    query: query,
    searchDebounce: const Duration(milliseconds: 20),
    refresh: const NoRefresh(),
    itemBuilder: (_, item, _) => Text('item $item'),
  ),
);

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
      var pageTwoCalls = 0;
      // Page 2 held, pages 0 and 1 already in, so reload depth is 2. Killing the held fetch frees
      // the list to ask again, hence the counter.
      final fetchPage = PageFetcher<int>((request) async {
        final pageIndex = request.pageIndex;
        if (pageIndex == 2) {
          pageTwoCalls++;
          await hold.future;
        }

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

      // Asked twice: once before the reload (superseded), once after. Only the second announces.
      check(pageTwoCalls).equals(2);
      check(observer.events.where((event) => event.startsWith('pageLoaded(index: 2,')).toList())
          .length
          .equals(1);
    });

    scenarioWidgets('a held search page does not land on the restored KeepCache list', (
      tester,
    ) async {
      final hold = Completer<List<int>>();
      final searchFetchPage = SearchPageFetcher<int>(
        (request) => request.pageIndex == 0 ? hold.future : Future.value(const <int>[]),
      );

      Widget build(String query) => ListSmith.async(
        fetchPage: pagedFetcher(const [
          [1, 2, 3],
        ]),
        search: AsyncSearch(fetchPage: searchFetchPage, cachePolicy: const KeepCachePolicy()),
        query: query,
        searchDebounce: const Duration(milliseconds: 20),
        refresh: const NoRefresh(),
        itemBuilder: (_, item, _) => Text('item $item'),
      );

      await pumpListSmith(tester, build(''));
      await settle(tester);
      await pumpListSmith(tester, build('q'));
      await settle(tester);
      await pumpListSmith(tester, build(''));
      await settle(tester);

      hold.complete(const [10, 11, 12]);
      await tester.idle();
      await drain(tester, frames: 16);

      // The restore cancels first, so the abandoned search page has nowhere to land. Without it,
      // hits for a deleted query show up under the feed.
      check(find.text('item 10').evaluate()).length.equals(0);
      check(find.text('item 11').evaluate()).length.equals(0);
      check(find.text('item 1').evaluate()).length.equals(1);
      check(find.text('item 3').evaluate()).length.equals(1);
    });

    scenarioWidgets('a KeepCache restore puts the normal cursor back, not the search one', (
      tester,
    ) async {
      final blocked = Completer<void>();
      final normalCursors = <int, List<Object?>>{};
      final fetchPage = PageFetcher<int>.withSignal((request) async {
        final pageIndex = request.pageIndex;
        normalCursors.putIfAbsent(pageIndex, () => []).add(request.previousSignal);
        // Page 2 never answers, so pagination parks there and the list keeps wanting it.
        if (pageIndex == 2) await blocked.future;

        return ([pageIndex], 'ncursor$pageIndex');
      });
      final searchFetchPage = SearchPageFetcher<int>.withSignal(
        (request) async => ([99], 'scursor${request.pageIndex}'),
      );

      Widget build(String query) => ListSmith.async(
        fetchPage: fetchPage,
        search: AsyncSearch(fetchPage: searchFetchPage, cachePolicy: const KeepCachePolicy()),
        query: query,
        searchDebounce: const Duration(milliseconds: 20),
        endPolicy: const StopOnNullSignalPolicy(),
        refresh: const NoRefresh(),
        itemBuilder: (_, item, _) => Text('item $item'),
      );

      await pumpListSmith(tester, build(''));
      await settle(tester);

      // Premise: pages 0 and 1 are in and page 2 is parked, asked once with page 1's cursor.
      check(normalCursors[2]).isNotNull().deepEquals(const ['ncursor1']);

      await pumpListSmith(tester, build('q'));
      await settle(tester);
      await pumpListSmith(tester, build(''));
      await settle(tester);
      await drain(tester, frames: 16);

      // The restore brings back the pages and the cursor that goes with them. Page 2 is asked again
      // from the same place, so the feed does not resume from the search's cursor or from scratch.
      check(normalCursors[2]).isNotNull().deepEquals(const ['ncursor1', 'ncursor1']);
      check(find.text('item 0').evaluate()).length.equals(1);
      check(find.text('item 99').evaluate()).length.equals(0);
    });

    scenarioWidgets('a KeepCache snapshot taken mid-fetch does not restore a spinner', (
      tester,
    ) async {
      final hold = Completer<List<int>>();
      final fetchPage = PageFetcher<int>((request) {
        if (request.pageIndex == 0) return Future.value(const [1, 2, 3]);

        return request.pageIndex == 1 ? hold.future : Future.value(const <int>[]);
      });

      Widget build(String query) => ListSmith.async(
        fetchPage: fetchPage,
        search: AsyncSearch(
          fetchPage: SearchPageFetcher(
            (request) async => request.pageIndex == 0 ? const [99] : const <int>[],
          ),
          cachePolicy: const KeepCachePolicy(),
        ),
        query: query,
        searchDebounce: const Duration(milliseconds: 20),
        refresh: const NoRefresh(),
        surfaces: AsyncListSurfaces(newPageLoadingBuilder: (_) => const Text('loading more')),
        itemBuilder: (_, item, _) => Text('item $item'),
      );

      // Page 1 is left in flight, so the snapshot is taken while isLoading is true.
      await pumpListSmith(tester, build(''));
      await settle(tester);
      await pumpListSmith(tester, build('q'));
      await settle(tester);
      await pumpListSmith(tester, build(''));
      await settle(tester);

      hold.complete(const [4, 5, 6]);
      await tester.idle();
      await drain(tester, frames: 16);

      // Pins the end state, not the mechanism: leaving search mid-fetch has to settle, not spin.
      // The re-fetch is what settles it today, so this passes without the seam too.
      check(find.text('loading more').evaluate()).length.equals(0);
      check(find.text('item 1').evaluate()).length.equals(1);
      check(find.text('item 4').evaluate()).length.equals(1);
    });

    scenarioWidgets('a held page does not land after a reset-to-first-page refresh', (
      tester,
    ) async {
      final hold = Completer<void>();
      final controller = ListSmithController();
      var pageTwoCalls = 0;
      final fetchPage = PageFetcher<int>((request) async {
        final pageIndex = request.pageIndex;
        if (pageIndex != 2) return [pageIndex * 1000 + 1];
        pageTwoCalls++;
        if (pageTwoCalls == 1) {
          await hold.future;

          return const [2001];
        }

        return const [2002];
      });

      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: fetchPage,
          controller: controller,
          endPolicy: const FixedPageCountPolicy(pageCount: 3),
          // No refresh: passed, so this runs the default PullToRefresh with its default
          // ResetToFirstPage reload, the pairing most consumers never change.
          itemBuilder: (_, item, _) => Text('item $item'),
        ),
      );
      await drain(tester, frames: 12);

      // Premise: pages 0 and 1 are in and page 2 is held.
      check(pageTwoCalls).equals(1);

      await controller.refresh();
      await drain(tester, frames: 16);

      hold.complete();
      await tester.idle();
      await drain(tester, frames: 12);

      // ResetToFirstPage throws the loaded pages away and starts again, so the page held from
      // before the refresh has nothing to attach to. Its body never shows, and page 2's fresh one
      // does.
      check(find.text('item 2001').evaluate()).length.equals(0);
      check(find.text('item 2002').evaluate()).length.equals(1);
      check(find.text('item 1').evaluate()).length.equals(1);
    });

    scenarioWidgets('a held page does not land on top of a depth-reload commit', (tester) async {
      final hold = Completer<void>();
      final controller = ListSmithController();
      var pageTwoCalls = 0;
      // Page 2 answers differently per attempt, so stale (20, 21) and fresh (6, 7) are told apart.
      final fetchPage = PageFetcher<int>((request) async {
        final pageIndex = request.pageIndex;
        // Bounded: page 2 no longer blocks pagination, and an endless fetcher would mint the very
        // ids checked absent below.
        if (pageIndex > 2) return const <int>[];
        if (pageIndex != 2) return [pageIndex * 3, pageIndex * 3 + 1, pageIndex * 3 + 2];
        pageTwoCalls++;
        if (pageTwoCalls == 1) {
          await hold.future;

          return const [20, 21, 22];
        }

        return const [6, 7, 8];
      });

      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: fetchPage,
          controller: controller,
          refresh: const PullToRefresh(reload: ReloadToCurrentDepth()),
          itemBuilder: (_, item, _) => Text('item $item'),
        ),
      );
      await drain(tester, frames: 12);

      await controller.refresh();
      await drain(tester, frames: 16);

      hold.complete();
      await tester.idle();
      await drain(tester, frames: 12);

      // The commit kills the held fetch, so its pre-reload body never lands. Page 2 is asked again.
      check(find.text('item 20').evaluate()).length.equals(0);
      check(find.text('item 22').evaluate()).length.equals(0);
      check(find.text('item 6').evaluate()).length.equals(1);
      check(find.text('item 0').evaluate()).length.equals(1);
      check(find.text('item 5').evaluate()).length.equals(1);
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

    scenarioWidgets('a depth reload does not commit over a list that moved on under it', (
      tester,
    ) async {
      final hold = Completer<void>();
      final source = _stampedSource(holdFor: (_, attempt) => attempt == 2 ? hold.future : null);
      final controller = ListSmithController();

      await _pumpStamped(tester, source, controller: controller);
      await drain(tester, frames: 12);
      check(_shown(tester)).deepEquals([1, 1001, 2001]);

      final refresh = controller.refresh();
      await drain(tester);
      await _pumpStamped(tester, source, controller: controller, query: 'x');
      await settle(tester);
      await drain(tester, frames: 12);
      // Premise: the query change restarted the stream and it loaded, while the reload still hangs.
      check(_shown(tester)).deepEquals([3, 1003, 2003]);

      hold.complete();
      await tester.idle();
      await drain(tester, frames: 12);
      await refresh;

      check(_shown(tester)).deepEquals([3, 1003, 2003]);
    });

    scenarioWidgets("a superseded depth reload leaves the new stream's first page alone", (
      tester,
    ) async {
      final holdReload = Completer<void>();
      final holdFirstPage = Completer<void>();
      final source = _stampedSource(
        holdFor: (pageIndex, attempt) => switch ((pageIndex, attempt)) {
          (_, 2) => holdReload.future,
          (0, 3) => holdFirstPage.future,
          _ => null,
        },
      );
      final controller = ListSmithController();

      await _pumpStamped(tester, source, controller: controller);
      await drain(tester, frames: 12);
      final refresh = controller.refresh();
      await drain(tester);
      await _pumpStamped(tester, source, controller: controller, query: 'x');
      await settle(tester);
      // Premise: the list is cleared and the new stream's page 0 is out there, held.
      check(_shown(tester)).isEmpty();

      // The reload lands first. Its commit used to cancel that page 0, leaving stale rows for good.
      holdReload.complete();
      await tester.idle();
      await drain(tester);
      holdFirstPage.complete();
      await tester.idle();
      await drain(tester, frames: 12);
      await refresh;

      check(_shown(tester)).deepEquals([3, 1003, 2003]);
    });

    scenarioWidgets('a depth reload of the search does not commit over a restored feed', (
      tester,
    ) async {
      // Under KeepCache the search's first load is attempt 2, so the reload is attempt 3.
      final hold = Completer<void>();
      final source = _stampedSource(
        holdFor: (_, attempt) => attempt == 3 ? hold.future : null,
        cachePolicy: const KeepCachePolicy(),
      );
      final controller = ListSmithController();

      await _pumpStamped(tester, source, controller: controller);
      await drain(tester, frames: 12);
      await _pumpStamped(tester, source, controller: controller, query: 'x');
      await settle(tester);
      await drain(tester, frames: 12);
      check(_shown(tester)).deepEquals([2, 1002, 2002]);

      final refresh = controller.refresh();
      await drain(tester);
      await _pumpStamped(tester, source, controller: controller);
      await settle(tester);
      // Premise: leaving search put the feed back while the search reload still hangs.
      check(_shown(tester)).deepEquals([1, 1001, 2001]);

      hold.complete();
      await tester.idle();
      await drain(tester, frames: 12);
      await refresh;

      check(_shown(tester)).deepEquals([1, 1001, 2001]);
    });

    scenarioWidgets('a refresh that meets a superseded reload starts its own', (tester) async {
      final hold = Completer<void>();
      final source = _stampedSource(holdFor: (_, attempt) => attempt == 2 ? hold.future : null);
      final controller = ListSmithController();

      await _pumpStamped(tester, source, controller: controller);
      await drain(tester, frames: 12);
      final first = controller.refresh();
      await drain(tester);
      await _pumpStamped(tester, source, controller: controller, query: 'x');
      await settle(tester);
      await drain(tester, frames: 12);
      check(_shown(tester)).deepEquals([3, 1003, 2003]);

      final before = source.log.length;
      final second = controller.refresh();
      await drain(tester, frames: 12);
      // A live reload would have been joined. A stale one is not worth joining: nothing it does lands.
      check(source.log.skip(before).where((entry) => entry.endsWith(':refresh')).length).equals(3);

      hold.complete();
      await tester.idle();
      await drain(tester, frames: 12);
      await (first, second).wait;

      check(_shown(tester)).deepEquals([4, 1004, 2004]);
    });

    scenarioWidgets('a superseded reload stops asking for the pages it had left', (tester) async {
      final hold = Completer<void>();
      final source = _stampedSource(
        holdFor: (pageIndex, attempt) => (pageIndex, attempt) == (0, 2) ? hold.future : null,
      );
      final controller = ListSmithController();

      await _pumpStamped(
        tester,
        source,
        controller: controller,
        reload: const ReloadToCurrentDepth(),
      );
      await drain(tester, frames: 12);
      final refresh = controller.refresh();
      await drain(tester);
      await _pumpStamped(
        tester,
        source,
        controller: controller,
        reload: const ReloadToCurrentDepth(),
        query: 'x',
      );
      await settle(tester);
      await drain(tester, frames: 12);

      hold.complete();
      await tester.idle();
      await drain(tester, frames: 12);
      await refresh;

      // Page 0 was in flight when the list moved on. Pages 1 and 2 were never asked for.
      check(source.log.where((entry) => entry.endsWith(':refresh')).toList())
          .deepEquals(['0#2:refresh']);
      check(_shown(tester)).deepEquals([3, 1002, 2002]);
    });

    scenarioWidgets('a superseded withSignal reload stops asking too', (tester) async {
      // A signal source reloads in order through its own loop, so that loop needs the same check.
      final hold = Completer<void>();
      final source = _stampedSource(
        holdFor: (pageIndex, attempt) => (pageIndex, attempt) == (0, 2) ? hold.future : null,
        signal: true,
      );
      final controller = ListSmithController();

      await _pumpStamped(tester, source, controller: controller);
      await drain(tester, frames: 12);
      final refresh = controller.refresh();
      await drain(tester);
      await _pumpStamped(tester, source, controller: controller, query: 'x');
      await settle(tester);
      await drain(tester, frames: 12);

      hold.complete();
      await tester.idle();
      await drain(tester, frames: 12);
      await refresh;

      check(source.log.where((entry) => entry.endsWith(':refresh')).toList())
          .deepEquals(['0#2:refresh']);
      check(_shown(tester)).deepEquals([3, 1002, 2002]);
    });

    scenarioWidgets('a depth reload finishing after the list is gone stays silent', (tester) async {
      final hold = Completer<void>();
      final source = _stampedSource(holdFor: (_, attempt) => attempt == 2 ? hold.future : null);
      final controller = ListSmithController();

      await _pumpStamped(tester, source, controller: controller);
      await drain(tester, frames: 12);
      final refresh = controller.refresh();
      await drain(tester);

      await pumpListSmith(tester, const SizedBox.shrink());
      hold.complete();
      await tester.idle();
      await drain(tester);
      await refresh;

      check(tester.takeException()).isNull();
    });
  });
}

typedef _HoldFor = Future<void>? Function(int pageIndex, int attempt);

typedef _StampedSource = ({
  PageFetcher<int> fetchPage,
  AsyncSearch<int> search,
  Map<int, int> attempts,
  List<String> log,
});

/// Stamps each page `page * 1000 + attempt`, so a re-fetched page is told from its first load, and
/// blocks the fetches [holdFor] picks. The feed and the search share the counter, so a query change
/// restarts the stream with the next stamp: the stand-in for anything that moves the list on under
/// a reload. `log` records every request as `page#attempt:trigger`. [signal] makes the feed a
/// `withSignal` source (always a null signal), which reloads through the in-order path.
_StampedSource _stampedSource({
  required _HoldFor holdFor,
  SearchCachePolicy cachePolicy = const ReplaceCachePolicy(),
  bool signal = false,
}) {
  final attempts = <int, int>{};
  final log = <String>[];
  Future<List<int>> fetch(PageRequest request) async {
    final attempt = attempts[request.pageIndex] = (attempts[request.pageIndex] ?? 0) + 1;
    log.add('${request.pageIndex}#$attempt:${request.trigger.name}');
    final hold = holdFor(request.pageIndex, attempt);
    if (hold != null) await hold;

    return [request.pageIndex * 1000 + attempt];
  }

  return (
    fetchPage: signal
        ? PageFetcher.withSignal((request) async => (await fetch(request), null))
        : PageFetcher(fetch),
    search: AsyncSearch(fetchPage: SearchPageFetcher(fetch), cachePolicy: cachePolicy),
    attempts: attempts,
    log: log,
  );
}

/// Pumps a three-page list over [source], with the pull's [reload] and a 20ms search debounce.
Future<void> _pumpStamped(
  WidgetTester tester,
  _StampedSource source, {
  required ListSmithController controller,
  Reload reload = const ReloadToCurrentDepth(concurrency: null),
  String query = '',
}) => pumpListSmith(
  tester,
  ListSmith.async(
    fetchPage: source.fetchPage,
    endPolicy: const FixedPageCountPolicy(pageCount: 3),
    refresh: PullToRefresh(reload: reload),
    search: source.search,
    controller: controller,
    query: query,
    searchDebounce: const Duration(milliseconds: 20),
    itemBuilder: (_, item, _) => Text('item $item'),
  ),
);

/// The stamps on screen, in order.
List<int> _shown(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((text) => text.data ?? '')
    .where((data) => data.startsWith('item '))
    .map((data) => int.parse(data.split(' ').last))
    .toList();

/// Pumps a cursor-driven async search list over [searchFetchPage] for [query]. The normal fetcher
/// is never reached (the query is always non-empty), and refresh is off so only the query drives
/// resets.
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

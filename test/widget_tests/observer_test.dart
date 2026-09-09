import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

import '../support/support.dart';

void main() {
  feature('ListSmith.async observer', () {
    scenarioWidgets('onPageLoaded fires with the page index and item count', (tester) async {
      final observer = RecordingListSmithObserver();
      await _pumpObserved(
        tester,
        observer,
        fetchPage: PageFetcher(
          (request) async => request.pageIndex == 0 ? const [1, 2, 3] : const <int>[],
        ),
      );
      await drain(tester);

      check(observer.events).contains('pageLoaded(index: 0, count: 3, search: false)');
    });

    scenarioWidgets('onError fires with the thrown error when a fetch fails', (tester) async {
      final observer = RecordingListSmithObserver();
      await _pumpObserved(
        tester,
        observer,
        fetchPage: PageFetcher((_) async => throw Exception('network')),
      );
      await drain(tester);

      check(observer.events).contains('error');
      check(observer.lastError).isA<Exception>();
    });

    scenarioWidgets('onReload reports refresh when the list is pulled', (tester) async {
      final observer = RecordingListSmithObserver();
      await _pumpObserved(
        tester,
        observer,
        fetchPage: PageFetcher(
          (request) async => request.pageIndex == 0 ? const [1, 2, 3] : const <int>[],
        ),
      );
      await drain(tester);

      await tester.fling(find.text('item 1'), const Offset(0, 300), 1000);
      for (var frame = 0; frame < 5; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      check(observer.events).contains('reload(refresh)');
    });

    scenarioOutlineWidgets(
      'onReload fires before any page of that reload is asked for',
      examples: const {
        'reset to first page': ResetToFirstPage(),
        'reload to current depth': ReloadToCurrentDepth(concurrency: null),
      },
      outline: (tester, reload) async {
        final observer = RecordingListSmithObserver();
        final controller = ListSmithController();
        // The fetcher writes into the observer's log, so one list holds the order of both.
        await _pumpObserved(
          tester,
          observer,
          fetchPage: PageFetcher((request) async {
            observer.events.add('fetch(${request.pageIndex}:${request.trigger.name})');

            return request.pageIndex == 0 ? const [1, 2, 3] : const <int>[];
          }),
          controller: controller,
          refresh: PullToRefresh(reload: reload),
        );
        await drain(tester);

        await controller.refresh();
        await drain(tester);

        final reloadAt = observer.events.indexOf('reload(refresh)');
        final firstFetchAt = observer.events.indexWhere((event) => event.endsWith(':refresh)'));
        check(reloadAt).isGreaterOrEqual(0);
        check(firstFetchAt).isGreaterThan(reloadAt);
      },
    );

    scenarioWidgets('a committed query change reports its reload after the commit events', (
      tester,
    ) async {
      final observer = RecordingListSmithObserver();
      final search = AsyncSearch(fetchPage: SearchPageFetcher((_) async => const [99]));
      await _pumpObserved(
        tester,
        observer,
        fetchPage: PageFetcher((_) async => const [1, 2, 3]),
        search: search,
      );
      await drain(tester);

      await _pumpObserved(
        tester,
        observer,
        fetchPage: PageFetcher((_) async => const [1, 2, 3]),
        search: search,
        query: 'ab',
      );
      await settle(tester);

      // Cause, then the mode edge, then the reload it started. Page loads left out.
      check(observer.events.where((event) => !event.startsWith('pageLoaded')).toList())
          .deepEquals(['queryCommitted(ab)', 'searchModeChanged(true)', 'reload(queryChanged)']);
    });

    scenarioWidgets('a clean KeepCache restore fires no reload, it fetches nothing', (
      tester,
    ) async {
      final observer = RecordingListSmithObserver();
      // Both sources end after one page, so nothing keeps paging after the restore.
      final search = AsyncSearch(
        fetchPage: SearchPageFetcher(
          (request) async => request.pageIndex == 0 ? const [99] : const <int>[],
        ),
        cachePolicy: const KeepCachePolicy(),
      );
      Future<void> pump(String query) => _pumpObserved(
        tester,
        observer,
        fetchPage: PageFetcher(
          (request) async => request.pageIndex == 0 ? const [1, 2, 3] : const <int>[],
        ),
        search: search,
        query: query,
      );

      await pump('');
      await drain(tester);
      await pump('ab');
      await settle(tester);
      await pump('');
      await settle(tester);

      // Entering search reloaded. Leaving it restored the snapshot, which is not a reload.
      check(observer.events.where((event) => event == 'reload(queryChanged)')).length.equals(1);
      check(observer.events.last).equals('searchModeChanged(false)');
    });

    scenarioWidgets('a KeepCache restore owing a refresh fires it, after the query facts', (
      tester,
    ) async {
      final observer = RecordingListSmithObserver();
      final controller = ListSmithController();
      final search = AsyncSearch(
        fetchPage: SearchPageFetcher(
          (request) async => request.pageIndex == 0 ? const [99] : const <int>[],
        ),
        cachePolicy: const KeepCachePolicy(),
      );
      Future<void> pump(String query) => _pumpObserved(
        tester,
        observer,
        fetchPage: PageFetcher(
          (request) async => request.pageIndex == 0 ? const [1, 2, 3] : const <int>[],
        ),
        search: search,
        query: query,
        controller: controller,
      );

      await pump('');
      await drain(tester);
      await pump('ab');
      await settle(tester);
      await controller.refresh();
      await drain(tester);
      observer.events.clear();
      await pump('');
      await settle(tester);

      check(observer.events.where((event) => !event.startsWith('pageLoaded')).toList())
          .deepEquals(['queryCommitted()', 'searchModeChanged(false)', 'reload(refresh)']);
    });

    scenarioWidgets('onReload reports invalidated for invalidate() and reset(), once each', (
      tester,
    ) async {
      final observer = RecordingListSmithObserver();
      final controller = ListSmithController();
      await _pumpObserved(
        tester,
        observer,
        fetchPage: PageFetcher(
          (request) async => request.pageIndex == 0 ? const [1, 2, 3] : const <int>[],
        ),
        controller: controller,
      );
      await drain(tester);

      await controller.invalidate();
      await drain(tester);
      await controller.reset();
      await drain(tester);
      // Two invalidates back to back: the second joins and books one rerun, so two events, not three.
      await [controller.invalidate(), controller.invalidate()].wait;
      await drain(tester);

      check(observer.events.where((event) => event == 'reload(invalidated)')).length.equals(4);
    });

    scenarioWidgets('onQueryCommitted and onSearchModeChanged fire on entering search', (
      tester,
    ) async {
      final observer = RecordingListSmithObserver();
      await _pumpObserved(
        tester,
        observer,
        fetchPage: PageFetcher((_) async => const [1, 2, 3]),
        search: AsyncSearch(fetchPage: SearchPageFetcher((_) async => const [99])),
      );
      await drain(tester);

      await _pumpObserved(
        tester,
        observer,
        fetchPage: PageFetcher((_) async => const [1, 2, 3]),
        search: AsyncSearch(fetchPage: SearchPageFetcher((_) async => const [99])),
        query: 'ab',
      );
      await settle(tester);

      check(observer.events).contains('queryCommitted(ab)');
      check(observer.events).contains('searchModeChanged(true)');
    });

    scenarioWidgets('a null observer stays silent and the list still renders', (tester) async {
      await _pumpObserved(
        tester,
        null,
        fetchPage: PageFetcher(
          (request) async => request.pageIndex == 0 ? const [1, 2, 3] : const <int>[],
        ),
      );
      await drain(tester);

      check(find.text('item 1').evaluate()).length.equals(1);
    });
  });
}

Future<void> _pumpObserved(
  WidgetTester tester,
  ListSmithObserver? observer, {
  required PageFetcher<int> fetchPage,
  Search<int> search = const NoSearch(),
  String query = '',
  ListSmithController? controller,
  Refresh refresh = const PullToRefresh(),
}) => pumpListSmith(
  tester,
  ListSmith.async(
    fetchPage: fetchPage,
    search: search,
    query: query,
    observer: observer,
    controller: controller,
    refresh: refresh,
    searchDebounce: const Duration(milliseconds: 20),
    itemBuilder: (_, item, _) => Text('item $item'),
  ),
);

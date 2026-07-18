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
          (pageIndex, _) async => pageIndex == 0 ? const [1, 2, 3] : const <int>[],
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
        fetchPage: PageFetcher((_, _) async => throw Exception('network')),
      );
      await drain(tester);

      check(observer.events).contains('error');
      check(observer.lastError).isA<Exception>();
    });

    scenarioWidgets('onRefresh fires when the list is pulled to refresh', (tester) async {
      final observer = RecordingListSmithObserver();
      await _pumpObserved(
        tester,
        observer,
        fetchPage: PageFetcher(
          (pageIndex, _) async => pageIndex == 0 ? const [1, 2, 3] : const <int>[],
        ),
      );
      await drain(tester);

      await tester.fling(find.text('item 1'), const Offset(0, 300), 1000);
      for (var frame = 0; frame < 5; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      check(observer.events).contains('refresh');
    });

    scenarioWidgets('onQueryCommitted and onSearchModeChanged fire on entering search', (
      tester,
    ) async {
      final observer = RecordingListSmithObserver();
      await _pumpObserved(
        tester,
        observer,
        fetchPage: PageFetcher((_, _) async => const [1, 2, 3]),
        search: AsyncSearch(fetchPage: SearchPageFetcher((_, _, _) async => const [99])),
      );
      await drain(tester);

      await _pumpObserved(
        tester,
        observer,
        fetchPage: PageFetcher((_, _) async => const [1, 2, 3]),
        search: AsyncSearch(fetchPage: SearchPageFetcher((_, _, _) async => const [99])),
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
          (pageIndex, _) async => pageIndex == 0 ? const [1, 2, 3] : const <int>[],
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
}) => pumpListSmith(
  tester,
  ListSmith.async(
    fetchPage: fetchPage,
    search: search,
    query: query,
    observer: observer,
    searchDebounce: const Duration(milliseconds: 20),
    itemBuilder: (_, item, _) => Text('item $item'),
  ),
);

import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

import '../support/bdd.dart';
import '../support/recording_list_smith_observer.dart';

void main() {
  feature('ListSmith.async observer', () {
    scenarioWidgets('onPageLoaded fires with the page index and item count', (tester) async {
      final observer = RecordingListSmithObserver();
      await _pumpObserved(
        tester,
        observer,
        fetchPage: (pageIndex, _) async => pageIndex == 0 ? const [1, 2, 3] : const <int>[],
      );
      await _drainPages(tester);

      check(observer.events).contains('pageLoaded(index: 0, count: 3, search: false)');
    });

    scenarioWidgets('onError fires with the thrown error when a fetch fails', (tester) async {
      final observer = RecordingListSmithObserver();
      await _pumpObserved(tester, observer, fetchPage: (_, _) async => throw Exception('network'));
      await _drainPages(tester);

      check(observer.events).contains('error');
      check(observer.lastError).isA<Exception>();
    });

    scenarioWidgets('onRefresh fires when the list is pulled to refresh', (tester) async {
      final observer = RecordingListSmithObserver();
      await _pumpObserved(
        tester,
        observer,
        fetchPage: (pageIndex, _) async => pageIndex == 0 ? const [1, 2, 3] : const <int>[],
      );
      await _drainPages(tester);

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
        fetchPage: (_, _) async => const [1, 2, 3],
        searchFetchPage: (_, _, _) async => const [99],
      );
      await _drainPages(tester);

      await _pumpObserved(
        tester,
        observer,
        fetchPage: (_, _) async => const [1, 2, 3],
        searchFetchPage: (_, _, _) async => const [99],
        query: 'ab',
      );
      await tester.pump(const Duration(milliseconds: 20));
      await _drainPages(tester);

      check(observer.events).contains('queryCommitted(ab)');
      check(observer.events).contains('searchModeChanged(true)');
    });

    scenarioWidgets('a null observer stays silent and the list still renders', (tester) async {
      await _pumpObserved(
        tester,
        null,
        fetchPage: (pageIndex, _) async => pageIndex == 0 ? const [1, 2, 3] : const <int>[],
      );
      await _drainPages(tester);

      check(find.text('item 1').evaluate()).length.equals(1);
    });
  });
}

Future<void> _pumpObserved(
  WidgetTester tester,
  ListSmithObserver? observer, {
  required PageFetcher<int> fetchPage,
  SearchPageFetcher<int>? searchFetchPage,
  String query = '',
}) => tester.pumpWidget(
  Directionality(
    textDirection: .ltr,
    child: MediaQuery(
      data: const MediaQueryData(),
      child: ListSmith.async(
        fetchPage: fetchPage,
        searchFetchPage: searchFetchPage,
        query: query,
        observer: observer,
        searchDebounce: const Duration(milliseconds: 20),
        itemBuilder: (_, item, _) => Text('item $item'),
      ),
    ),
  ),
);

/// Pumps a few frames so the post-frame first fetch, its async result, and any triggered next fetch
/// all settle. The neutral spinner animates forever, so we drive fixed pumps, never `pumpAndSettle`.
Future<void> _drainPages(WidgetTester tester) async {
  for (var frame = 0; frame < 4; frame++) {
    await tester.pump();
  }
}

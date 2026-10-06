import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

import '../../support/support.dart';

void main() {
  feature('ListSmith.async surfaces', () {
    scenarioOutlineWidgets<({PageFetcher<int> fetchPage, String shownText})>(
      'renders the right surface for the source state',
      examples: {
        'the first page of items': (
          fetchPage: PageFetcher(
            (request) async => request.pageIndex == 0 ? const [1, 2, 3] : const <int>[],
          ),
          shownText: 'item 1',
        ),
        'the empty surface when the source has no items': (
          fetchPage: PageFetcher((_) async => const <int>[]),
          shownText: 'No items',
        ),
        'the no-more footer once every page has loaded': (
          fetchPage: PageFetcher(
            (request) async => request.pageIndex == 0 ? const [1, 2, 3] : const <int>[],
          ),
          shownText: 'No more items',
        ),
      },
      outline: (tester, example) async {
        await _pumpList(tester, example.fetchPage);
        await drain(tester);

        check(find.text(example.shownText).evaluate()).length.equals(1);
      },
    );

    scenarioWidgets('shows the error surface, then retry recovers to the items', (tester) async {
      var calls = 0;
      await _pumpList(
        tester,
        PageFetcher((request) async {
          calls++;
          if (calls == 1) throw Exception('network');

          return request.pageIndex == 0 ? const [1, 2, 3] : const <int>[];
        }),
      );
      await drain(tester);

      check(find.text('Something went wrong').evaluate()).length.equals(1);
      check(find.text('Retry').evaluate()).length.equals(1);

      await tester.tap(find.text('Retry'));
      await drain(tester);

      check(find.text('item 1').evaluate()).length.equals(1);
    });

    scenarioWidgets("a later page's Retry asks for that page again and shows its rows", (
      tester,
    ) async {
      final server = FakeServer([1, 2, 3, 4, 5, 6])..failing.add((1, 1));
      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: server.offsetLateFetcher,
          itemIdGetter: (item) => item,
          pageSize: 3,
          itemBuilder: (_, item, _) => Text('item $item'),
        ),
      );
      await drain(tester);
      // Premise: page 1 failed under page 0's rows.
      check(find.text('item 3').evaluate()).length.equals(1);
      check(find.text('item 4').evaluate()).isEmpty();

      await tester.tap(find.text('Retry'));
      await drain(tester);

      check(server.attempts[1]).equals(2);
      check(find.text('item 4').evaluate()).length.equals(1);
    });

    scenarioWidgets(
      "a fetcher's Error isn't caught, so it reaches the app instead of the error surface",
      (tester) async {
        final observer = RecordingListSmithObserver();
        final uncaught = <Object>[];
        // An uncaught Error lands in the app's zone handler, so this test plays that part.
        await runZonedGuarded(() async {
          await pumpListSmith(
            tester,
            ListSmith.async(
              fetchPage: PageFetcher((_) async => throw StateError('a bug in the fetcher')),
              itemIdGetter: (item) => item,
              observer: observer,
              itemBuilder: (_, item, _) => Text('item $item'),
            ),
          );
          await drain(tester);
        }, (error, _) => uncaught.add(error));

        check(uncaught).single.isA<StateError>();
        check(find.text('Something went wrong').evaluate()).isEmpty();
        check(observer.events.contains('error')).isFalse();
      },
    );
  });
}

Future<void> _pumpList(WidgetTester tester, PageFetcher<int> fetchPage) => pumpListSmith(
  tester,
  ListSmith.async(
    fetchPage: fetchPage,
    itemIdGetter: (item) => item,
    itemBuilder: (_, item, _) => Text('item $item'),
  ),
);

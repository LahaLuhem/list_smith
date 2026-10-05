import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

import '../support/support.dart';

void main() {
  feature('ListSmith.async EmptyPageBehaviour', () {
    // Serves `pages` by 0-based index (empty beyond the end) and records every index requested, so a
    // test can assert exactly how far the list paged on its own.
    ({PageFetcher<int> fetchPage, List<int> requested}) recordingFetcher(List<List<int>> pages) {
      final requested = <int>[];
      final fetchPage = PageFetcher<int>((request) async {
        requested.add(request.pageIndex);

        return request.pageIndex < pages.length ? pages[request.pageIndex] : const <int>[];
      });

      return (fetchPage: fetchPage, requested: requested);
    }

    scenarioWidgets('AdvanceToFirstNonEmpty pages past empty pages to the first with items', (
      tester,
    ) async {
      final fetcher = recordingFetcher(const <List<int>>[
        [],
        [],
        [1, 2],
      ]);

      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: fetcher.fetchPage,
          itemIdGetter: (item) => item,
          endPolicy: const StopOnEmptyPagesPolicy(emptyRunBeforeEnd: 5),
          onEmptyPage: const AdvanceToFirstNonEmpty(),
          refresh: const NoRefresh(),
          itemBuilder: (_, item, _) => Text('item $item'),
        ),
      );
      await drain(tester, frames: 12);

      // Advanced through the 2 empty pages (0, 1) to the 1st page with data (2) and rendered it. The
      // pager may fetch more to fill the viewport, which isn't the point here.
      check(fetcher.requested.take(3)).deepEquals(const [0, 1, 2]);
      check(find.text('item 1').evaluate()).length.equals(1);
      check(find.text('item 2').evaluate()).length.equals(1);
    });

    scenarioWidgets('a custom first-page loading surface covers the advance', (tester) async {
      final holdCompleter = Completer<List<int>>();
      final fetchPage = PageFetcher<int>((request) {
        if (request.pageIndex == 0) return Future.value(const <int>[]);

        return request.pageIndex == 1 ? holdCompleter.future : Future.value(const <int>[]);
      });

      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: fetchPage,
          itemIdGetter: (item) => item,
          endPolicy: const StopOnEmptyPagesPolicy(emptyRunBeforeEnd: 5),
          onEmptyPage: const AdvanceToFirstNonEmpty(),
          refresh: const NoRefresh(),
          surfaces: AsyncListSurfaces(firstPageLoadingBuilder: (_) => const Text('my loader')),
          itemBuilder: (_, item, _) => Text('item $item'),
        ),
      );
      await drain(tester, frames: 12);

      // Page 0 came back empty and the behaviour is still paging on, so the loading slot is showing
      // and the consumer's override is what gets drawn there, not the neutral default.
      check(find.text('my loader').evaluate()).length.equals(1);

      holdCompleter.complete(const [1, 2]);
      await tester.idle();
      await drain(tester, frames: 12);
      check(find.text('my loader').evaluate()).length.equals(0);
      check(find.text('item 1').evaluate()).length.equals(1);
    });

    scenarioWidgets(
      "the app's ScrollController stays attached while the list pages past an empty page",
      (tester) async {
        final scrollController = ScrollController();
        addTearDown(scrollController.dispose);
        final holdCompleter = await _pumpPagingPastEmpty(
          tester,
          scrollConfig: ListScrollConfig(controller: scrollController),
        );

        check(scrollController.hasClients).isTrue();
        holdCompleter.complete(const [1, 2]);
        await drain(tester);
      },
    );

    scenarioWidgets(
      'the loader shown while the list pages past an empty page holds still under a drag',
      (tester) async {
        // Bouncing physics, so anything that takes the drag visibly moves.
        final holdCompleter = await _pumpPagingPastEmpty(
          tester,
          scrollConfig: const ListScrollConfig(physics: BouncingScrollPhysics()),
        );
        final restingRect = tester.getRect(find.text('my loader'));

        final gesture = await tester.startGesture(tester.getCenter(find.text('my loader')));
        for (var step = 0; step < 6; step++) {
          await gesture.moveBy(const Offset(0, 30));
          await tester.pump(const Duration(milliseconds: 16));
        }
        final draggedRect = tester.getRect(find.text('my loader'));
        await gesture.up();

        check(draggedRect).equals(restingRect);
        holdCompleter.complete(const [1, 2]);
        await drain(tester);
      },
    );

    scenarioWidgets('the default (ShowEmptySurface) stops on the first empty page', (tester) async {
      final fetcher = recordingFetcher(const <List<int>>[
        [],
        [1, 2],
      ]);

      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: fetcher.fetchPage,
          itemIdGetter: (item) => item,
          endPolicy: const StopOnEmptyPagesPolicy(emptyRunBeforeEnd: 5),
          // onEmptyPage omitted: defaults to ShowEmptySurface.
          refresh: const NoRefresh(),
          itemBuilder: (_, item, _) => Text('item $item'),
        ),
      );
      await drain(tester, frames: 12);

      // No advance: the empty page shows the empty surface and page 1's data is never requested.
      check(fetcher.requested).deepEquals(const [0]);
      check(find.text('item 1').evaluate()).length.equals(0);
    });

    scenarioWidgets('maxPages caps the advance, then shows the empty surface', (tester) async {
      final fetcher = recordingFetcher(const <List<int>>[
        [],
        [],
        [],
        [1, 2],
      ]);

      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: fetcher.fetchPage,
          itemIdGetter: (item) => item,
          endPolicy: const StopOnEmptyPagesPolicy(emptyRunBeforeEnd: 10),
          onEmptyPage: const AdvanceToFirstNonEmpty(maxPages: 2),
          refresh: const NoRefresh(),
          itemBuilder: (_, item, _) => Text('item $item'),
        ),
      );
      await drain(tester, frames: 12);

      // Gave up after fetching maxPages pages (0 and 1). The data on page 3 is never reached.
      check(fetcher.requested).deepEquals(const [0, 1]);
      check(find.text('item 1').evaluate()).length.equals(0);
    });

    scenarioWidgets('advancing is gated by the end policy, not just the behaviour', (tester) async {
      final fetcher = recordingFetcher(const <List<int>>[
        [],
        [1, 2],
      ]);

      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: fetcher.fetchPage,
          itemIdGetter: (item) => item,
          // The default policy ends on the 1st empty page, so there is no next page to advance to.
          onEmptyPage: const AdvanceToFirstNonEmpty(),
          refresh: const NoRefresh(),
          itemBuilder: (_, item, _) => Text('item $item'),
        ),
      );
      await drain(tester, frames: 12);

      check(fetcher.requested).deepEquals(const [0]);
      check(find.text('item 1').evaluate()).length.equals(0);
    });
  });
}

/// Pumps a list whose page 0 is empty and whose page 1 holds, so it sits paging past the empty one.
Future<Completer<List<int>>> _pumpPagingPastEmpty(
  WidgetTester tester, {
  required ListScrollConfig scrollConfig,
}) async {
  final holdCompleter = Completer<List<int>>();
  await pumpListSmith(
    tester,
    ListSmith.async(
      fetchPage: PageFetcher(
        (request) => request.pageIndex == 0 ? Future.value(const <int>[]) : holdCompleter.future,
      ),
      itemIdGetter: (item) => item,
      endPolicy: const StopOnEmptyPagesPolicy(emptyRunBeforeEnd: 5),
      onEmptyPage: const AdvanceToFirstNonEmpty(),
      scroll: scrollConfig,
      surfaces: AsyncListSurfaces(firstPageLoadingBuilder: (_) => const Text('my loader')),
      itemBuilder: (_, item, _) => Text('item $item'),
    ),
  );
  await drain(tester, frames: 12);
  // Premise: page 0 came back empty and the list is still paging on.
  check(find.text('my loader').evaluate()).length.equals(1);

  return holdCompleter;
}

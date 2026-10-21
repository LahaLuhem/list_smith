import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

import '../../../support/support.dart';

void main() {
  feature('ListSmith.async paging on after removals', () {
    scenarioOutlineWidgets<_RowRemover>(
      'the rows a removal pulls up still show when the next page loads',
      examples: _rowRemovers,
      outline: (tester, remove) async {
        final server = FakeServer(_range(0, 14));
        final scrollController = ScrollController();
        addTearDown(scrollController.dispose);
        final controller = await _pumpList(
          tester,
          fetchPage: server.offsetLateFetcher,
          scrollController: scrollController,
        );
        check(server.asked(3)).isFalse(); // page 3 waits for a scroll

        server.store.remove(1);
        remove(controller);
        await tester.pump();

        check(await _allShownItems(tester, scrollController)).deepEquals(server.store);
      },
    );

    scenarioWidgets('the same while the removed row is still animating out', (tester) async {
      final server = FakeServer(_range(0, 14));
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      final controller = await _pumpList(
        tester,
        fetchPage: server.offsetLateFetcher,
        scrollController: scrollController,
        isTransitionOn: true,
      );

      server.store.remove(1);
      controller.remove(1);
      await tester.pump(); // the exit starts a frame on
      await scrollToEnd(tester, scrollController); // no time passes, so the exit is still running
      final isAskedMidExit = server.asked(3);
      await tester.pump(const Duration(milliseconds: 400));

      check(isAskedMidExit).isTrue();
      check(await _allShownItems(tester, scrollController)).deepEquals(server.store);
    });

    scenarioOutlineWidgets<_RowRemover>(
      'the same when the removal comes in while the next page is out',
      examples: _rowRemovers,
      outline: (tester, remove) async {
        final server = FakeServer(_range(0, 14));
        final pageHoldCompleter = server.hold(2, attempt: 1);
        final scrollController = ScrollController();
        addTearDown(scrollController.dispose);
        final controller = await _pumpList(
          tester,
          fetchPage: server.offsetLateFetcher,
          scrollController: scrollController,
          rowHeight: _shortRowHeight,
        );
        check(server.asked(2)).isTrue();

        server.store.remove(1);
        remove(controller);
        await tester.pump();
        await release(tester, [pageHoldCompleter]);

        check(await _allShownItems(tester, scrollController)).deepEquals(server.store);
      },
    );

    scenarioWidgets('the same while the removed row is still animating out as that page lands', (
      tester,
    ) async {
      final server = FakeServer(_range(0, 14));
      final pageHoldCompleter = server.hold(2, attempt: 1);
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      final controller = await _pumpList(
        tester,
        fetchPage: server.offsetLateFetcher,
        scrollController: scrollController,
        rowHeight: _shortRowHeight,
        isTransitionOn: true,
      );

      server.store.remove(1);
      controller.remove(1);
      await tester.pump(); // the exit starts a frame on
      await tester.pump(const Duration(milliseconds: 50));
      final isLandingMidExit = find.text('item 1').evaluate().isNotEmpty;
      await release(tester, [pageHoldCompleter]);
      await tester.pump(const Duration(milliseconds: 400));

      check(isLandingMidExit).isTrue();
      check(await _allShownItems(tester, scrollController)).deepEquals(server.store);
    });

    scenarioWidgets('the same when a save already out lands while the next page is out', (
      tester,
    ) async {
      final server = FakeServer(_range(0, 14));
      final pageHoldCompleter = server.hold(3, attempt: 1);
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      final controller = await _pumpList(
        tester,
        fetchPage: server.offsetLateFetcher,
        scrollController: scrollController,
      );
      final saveCompleter = Completer<void>();
      unawaited(controller.removeAsync(1, commit: saveCompleter.future));
      await tester.pump();
      await scrollToEnd(tester, scrollController);
      check(server.asked(3)).isTrue();

      server.store.remove(1);
      await release(tester, [pageHoldCompleter]);
      saveCompleter.complete();

      check(await _allShownItems(tester, scrollController)).deepEquals(server.store);
    });

    scenarioWidgets('the same when a later save fails while the next page is out', (tester) async {
      final server = FakeServer(_range(0, 14));
      final pageHoldCompleter = server.hold(3, attempt: 1);
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      final controller = await _pumpList(
        tester,
        fetchPage: server.offsetLateFetcher,
        scrollController: scrollController,
      );
      final saveCompleter = Completer<void>();
      server.store.remove(4);
      controller.remove(4);
      unawaited(controller.removeAsync(1, commit: saveCompleter.future));
      await tester.pump();
      await scrollToEnd(tester, scrollController);
      check(server.asked(3)).isTrue();

      saveCompleter.completeError(Exception('save failed'));
      await tester.pump();
      await release(tester, [pageHoldCompleter]);

      check(await _allShownItems(tester, scrollController)).deepEquals(server.store);
    });

    scenarioWidgets('the same for a new item a later page was read after', (tester) async {
      final server = FakeServer(_range(0, 14));
      final pageHoldCompleter = server.hold(4, attempt: 1);
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      final controller = await _pumpList(
        tester,
        fetchPage: server.offsetLateFetcher,
        scrollController: scrollController,
      );
      server.store.insert(1, 100);
      controller.upsert(100);
      await tester.pump();
      await scrollToEnd(tester, scrollController);
      check(server.asked(4)).isTrue(); // premise: page 3 was read after it, page 4 waits

      server.store.remove(100);
      controller.remove(100);
      await tester.pump();
      await release(tester, [pageHoldCompleter]);

      check(await _allShownItems(tester, scrollController)).deepEquals(server.store);
    });

    scenarioWidgets('removing every row on screen shows the rows after them, not the empty one', (
      tester,
    ) async {
      final server = FakeServer(_range(0, 14));
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      final controller = await _pumpList(
        tester,
        fetchPage: server.offsetLateFetcher,
        scrollController: scrollController,
      );

      for (final item in _range(0, 8)) {
        server.store.remove(item);
        controller.remove(item);
      }
      await tester.idle();
      await drain(tester, frames: 12);

      check(await _allShownItems(tester, scrollController)).deepEquals(server.store);
    });

    scenarioWidgets('the same in search results', (tester) async {
      final server = FakeServer(_range(0, 28));
      final searchPageIndexes = <int>[];
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      final controller = await _pumpList(
        tester,
        fetchPage: server.offsetLateFetcher,
        scrollController: scrollController,
        search: AsyncSearch(fetchPage: _evenRowsFetcher(server, searchPageIndexes)),
        query: 'even',
      );
      check(searchPageIndexes).not((it) => it.contains(3));

      server.store.remove(4);
      controller.remove(4);
      await tester.pump();

      check(await _allShownItems(tester, scrollController))
          .deepEquals(server.store.where((item) => item.isEven));
    });

    scenarioWidgets('the same in a feed kept while searching, once it comes back', (tester) async {
      final server = FakeServer(_range(0, 14));
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      final controller = ListSmithController<int>();
      Future<void> pumpWithQuery(String query) async {
        await _pumpList(
          tester,
          fetchPage: server.offsetLateFetcher,
          scrollController: scrollController,
          controller: controller,
          search: AsyncSearch(
            fetchPage: _evenRowsFetcher(server, []),
            cachePolicy: const KeepCachePolicy(),
          ),
          query: query,
        );
        await settle(tester);
      }

      await pumpWithQuery('');
      await pumpWithQuery('even');
      server.store.remove(2);
      controller.remove(2);
      await pumpWithQuery('');

      check(await _allShownItems(tester, scrollController)).deepEquals(server.store);
    });

    scenarioOutlineWidgets<_SignalFetcherGetter>(
      'the same on a withSignal list',
      examples: _signalFetchers,
      outline: (tester, fetcherOf) async {
        final server = FakeServer(_range(0, 14));
        final scrollController = ScrollController();
        addTearDown(scrollController.dispose);
        final controller = await _pumpList(
          tester,
          fetchPage: fetcherOf(server),
          scrollController: scrollController,
        );
        check(server.asked(3)).isFalse();

        server.store.remove(1);
        controller.remove(1);
        await tester.pump();

        check(await _allShownItems(tester, scrollController)).deepEquals(server.store);
      },
    );

    scenarioWidgets('the same after a depth reload, with an offset as the cursor', (tester) async {
      final server = FakeServer(_range(0, 14));
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      final controller = await _pumpList(
        tester,
        fetchPage: server.offsetCursorFetcher,
        scrollController: scrollController,
        refresh: const PullToRefresh(reload: ReloadToCurrentDepth()),
      );
      unawaited(controller.refresh());
      await tester.idle();
      await drain(tester, frames: 12);
      check(server.attempts[2]).equals(2); // premise: the reload wrote page 2, the one read again

      server.store.remove(4);
      controller.remove(4);
      await tester.pump();

      check(await _allShownItems(tester, scrollController)).deepEquals(server.store);
    });

    scenarioWidgets('with a removal still saving, the list still stops at its 1st empty page', (
      tester,
    ) async {
      final server = FakeServer(_range(0, 14));
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      final controller = await _pumpList(
        tester,
        fetchPage: server.offsetLateFetcher,
        scrollController: scrollController,
      );

      server.store.remove(1);
      unawaited(controller.removeAsync(1, commit: Completer<void>().future));
      await tester.pump();
      await scrollToEnd(tester, scrollController);

      final firstEmptyPageIndex = (server.store.length / _pageSize).ceil();
      check(server.asked(firstEmptyPageIndex)).isTrue();
      check(server.asked(firstEmptyPageIndex + 1)).isFalse();
    });

    scenarioWidgets('while a save is out, each page reads the page before again only once', (
      tester,
    ) async {
      final server = FakeServer(_range(0, 14));
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      final controller = await _pumpList(
        tester,
        fetchPage: server.offsetLateFetcher,
        scrollController: scrollController,
      );

      server.store.remove(1);
      unawaited(controller.removeAsync(1, commit: Completer<void>().future));
      await tester.pump();

      check(await _allShownItems(tester, scrollController)).deepEquals(server.store);
      check(server.attempts.values).every((it) => it.isLessOrEqual(2));
    });

    scenarioWidgets('a new item alone reads no page again', (tester) async {
      final server = FakeServer(_range(0, 14));
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      final controller = await _pumpList(
        tester,
        fetchPage: server.offsetLateFetcher,
        scrollController: scrollController,
      );
      check(server.asked(3)).isFalse(); // page 3 waits for a scroll

      server.store.insert(1, 100);
      controller.upsert(100);
      await tester.pump();
      await scrollToEnd(tester, scrollController);

      check(server.attempts.values).every((it) => it.equals(1));
    });
  });

  feature('ListSmith.async depth reloads after removals', () {
    scenarioOutlineWidgets<int?>(
      'the rows a removal pulls up still show when it lands mid-reload',
      examples: const {'one page at a time': 1, 'all at once': null},
      outline: (tester, concurrency) async {
        final server = FakeServer(_range(0, 8));
        final scrollController = ScrollController();
        addTearDown(scrollController.dispose);
        final controller = await _pumpList(
          tester,
          fetchPage: server.offsetLateFetcher,
          scrollController: scrollController,
          rowHeight: _shortRowHeight,
          endPolicy: const FixedPageCountPolicy(pageCount: 2),
          refresh: PullToRefresh(reload: ReloadToCurrentDepth(concurrency: concurrency)),
        );
        final firstPageHoldCompleter = server.hold(0, attempt: 2);
        final secondPageHoldCompleter = server.hold(1, attempt: 2);
        unawaited(controller.refresh());
        await tester.idle();
        await drain(tester, frames: 4);
        await release(tester, [firstPageHoldCompleter]);

        server.store.remove(1); // after page 0 is read, before page 1 is
        controller.remove(1);
        await tester.pump();
        await release(tester, [secondPageHoldCompleter]);

        check(await _allShownItems(tester, scrollController))
            .deepEquals(server.store.take(_pageSize * 2));
      },
    );

    scenarioOutlineWidgets<_SignalFetcherGetter>(
      'the same on a withSignal list',
      examples: _signalFetchers,
      outline: (tester, fetcherOf) async {
        final server = FakeServer(_range(0, 8));
        final scrollController = ScrollController();
        addTearDown(scrollController.dispose);
        final controller = await _pumpList(
          tester,
          fetchPage: fetcherOf(server),
          scrollController: scrollController,
          rowHeight: _shortRowHeight,
          endPolicy: const FixedPageCountPolicy(pageCount: 3),
          refresh: const PullToRefresh(reload: ReloadToCurrentDepth()),
        );
        final lastPageHoldCompleter = server.hold(2, attempt: 2);
        unawaited(controller.refresh());
        await tester.idle();
        await drain(tester, frames: 4);
        check(server.attempts[2]).equals(2); // premise: pages 0 and 1 are back, page 2 is out

        server.store.remove(4); // from page 1, so reading it again needs its own signal
        controller.remove(4);
        await tester.pump();
        await release(tester, [lastPageHoldCompleter]);

        check(await _allShownItems(tester, scrollController))
            .deepEquals(server.store.take(_pageSize * 3));
      },
    );

    scenarioWidgets('the same when its save is out from before the reload', (tester) async {
      final server = FakeServer(_range(0, 8));
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      final controller = await _pumpList(
        tester,
        fetchPage: server.offsetLateFetcher,
        scrollController: scrollController,
        rowHeight: _shortRowHeight,
        endPolicy: const FixedPageCountPolicy(pageCount: 2),
        refresh: const PullToRefresh(reload: ReloadToCurrentDepth()),
      );
      unawaited(controller.removeAsync(1, commit: Completer<void>().future));
      await tester.pump();
      final firstPageHoldCompleter = server.hold(0, attempt: 2);
      final secondPageHoldCompleter = server.hold(1, attempt: 2);
      unawaited(controller.refresh());
      await tester.idle();
      await drain(tester, frames: 4);
      await release(tester, [firstPageHoldCompleter]);

      server.store.remove(1); // the save reaches the server between the 2 reads
      await release(tester, [secondPageHoldCompleter]);

      check(await _allShownItems(tester, scrollController))
          .deepEquals(server.store.take(_pageSize * 2));
    });

    scenarioWidgets('the same when it lands while the page before is out', (tester) async {
      final server = FakeServer(_range(0, 8));
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      final controller = await _pumpList(
        tester,
        fetchPage: server.offsetEarlyFetcher,
        scrollController: scrollController,
        rowHeight: _shortRowHeight,
        endPolicy: const FixedPageCountPolicy(pageCount: 2),
        refresh: const PullToRefresh(reload: ReloadToCurrentDepth()),
      );
      final firstPageHoldCompleter = server.hold(0, attempt: 2);
      unawaited(controller.refresh());
      await tester.idle();
      await drain(tester, frames: 4);

      server.store.remove(1); // page 0 was read as it went out, so before this
      controller.remove(1);
      await tester.pump();
      await release(tester, [firstPageHoldCompleter]);

      check(await _allShownItems(tester, scrollController))
          .deepEquals(server.store.take(_pageSize * 2));
    });

    scenarioWidgets('the same when the app tells the list only after the next page landed', (
      tester,
    ) async {
      final server = FakeServer(_range(0, 8));
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      final controller = await _pumpList(
        tester,
        fetchPage: server.offsetLateFetcher,
        scrollController: scrollController,
        rowHeight: _shortRowHeight,
        endPolicy: const FixedPageCountPolicy(pageCount: 3),
        refresh: const PullToRefresh(reload: ReloadToCurrentDepth()),
      );
      final secondPageHoldCompleter = server.hold(1, attempt: 2);
      final lastPageHoldCompleter = server.hold(2, attempt: 2);
      unawaited(controller.refresh());
      await tester.idle();
      await drain(tester, frames: 4);

      server.store.remove(1); // the app's delete call reaches the server while page 1 is out
      await release(tester, [secondPageHoldCompleter]);
      check(server.attempts[2]).equals(2);
      controller.remove(1);
      await tester.pump();
      await release(tester, [lastPageHoldCompleter]);

      check(await _allShownItems(tester, scrollController)).deepEquals(server.store);
    });

    scenarioWidgets('the same when its exit ends after the next page landed', (tester) async {
      final server = FakeServer(_range(0, 8));
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      final controller = await _pumpList(
        tester,
        fetchPage: server.offsetLateFetcher,
        scrollController: scrollController,
        rowHeight: _shortRowHeight,
        isTransitionOn: true,
        endPolicy: const FixedPageCountPolicy(pageCount: 3),
        refresh: const PullToRefresh(reload: ReloadToCurrentDepth()),
      );
      unawaited(controller.removeAsync(1, commit: Completer<void>().future));
      await tester.pump(); // the exit starts a frame on
      final secondPageHoldCompleter = server.hold(1, attempt: 2);
      final lastPageHoldCompleter = server.hold(2, attempt: 2);
      unawaited(controller.refresh());
      await tester.idle();
      await drain(tester, frames: 4);

      server.store.remove(1); // the save reaches the server while page 1 is out
      await release(tester, [secondPageHoldCompleter]);
      check(server.attempts[2]).equals(2);
      await tester.pump(const Duration(milliseconds: 400));
      await release(tester, [lastPageHoldCompleter]);

      check(await _allShownItems(tester, scrollController)).deepEquals(server.store);
    });

    scenarioWidgets('the same for a new item on no page', (tester) async {
      final server = FakeServer(_range(0, 14));
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      final controller = await _pumpList(
        tester,
        fetchPage: server.offsetLateFetcher,
        scrollController: scrollController,
        rowHeight: _shortRowHeight,
        endPolicy: const FixedPageCountPolicy(pageCount: 3),
        refresh: const PullToRefresh(reload: ReloadToCurrentDepth()),
      );
      final secondPageHoldCompleter = server.hold(1, attempt: 2);
      final lastPageHoldCompleter = server.hold(2, attempt: 2);
      unawaited(controller.refresh());
      await tester.idle();
      await drain(tester, frames: 4);

      server.store.insert(1, 100); // after page 0 is read, so the reload reads it on no page
      controller.upsert(100);
      await tester.pump();
      await release(tester, [secondPageHoldCompleter]);
      server.store.remove(100);
      controller.remove(100);
      await tester.pump();
      await release(tester, [lastPageHoldCompleter]);

      check(await _allShownItems(tester, scrollController))
          .deepEquals(server.store.take(_pageSize * 3));
    });

    scenarioWidgets('a read that cannot line the pages up keeps the old list', (tester) async {
      final server = FakeServer(_range(0, 8));
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      final controller = await _pumpList(
        tester,
        fetchPage: server.offsetLateFetcher,
        scrollController: scrollController,
        rowHeight: _shortRowHeight,
        endPolicy: const FixedPageCountPolicy(pageCount: 2),
        refresh: const PullToRefresh(reload: ReloadToCurrentDepth()),
      );
      final secondPageHoldCompleter = server.hold(1, attempt: 2);
      server.failing.add((0, 3));
      unawaited(controller.refresh());
      await tester.idle();
      await drain(tester, frames: 4);

      server.store.remove(1);
      controller.remove(1);
      await tester.pump();
      await release(tester, [secondPageHoldCompleter]);

      check(server.attempts[0]).equals(3);
      check(await _allShownItems(tester, scrollController))
          .deepEquals(_range(0, 5).where((item) => item != 1));
    });

    scenarioWidgets('a removal below a boundary reads nothing again above it', (tester) async {
      final server = FakeServer(_range(0, 8));
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      final controller = await _pumpList(
        tester,
        fetchPage: server.offsetLateFetcher,
        scrollController: scrollController,
        rowHeight: _shortRowHeight,
        endPolicy: const FixedPageCountPolicy(pageCount: 2),
        refresh: const PullToRefresh(reload: ReloadToCurrentDepth()),
      );
      final secondPageHoldCompleter = server.hold(1, attempt: 2);
      unawaited(controller.refresh());
      await tester.idle();
      await drain(tester, frames: 4);

      server.store.remove(4);
      controller.remove(4);
      await tester.pump();
      await release(tester, [secondPageHoldCompleter]);

      check(await _allShownItems(tester, scrollController))
          .deepEquals(server.store.take(_pageSize * 2));
      check(server.attempts[0]).equals(2);
    });

    scenarioWidgets('many removals mid-reload still leave every row in order', (tester) async {
      final server = FakeServer(_range(0, 14));
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      final controller = await _pumpList(
        tester,
        fetchPage: server.offsetLateFetcher,
        scrollController: scrollController,
        rowHeight: _shortRowHeight,
        endPolicy: const FixedPageCountPolicy(pageCount: 3),
        refresh: const PullToRefresh(reload: ReloadToCurrentDepth()),
      );
      void remove(int item) {
        server.store.remove(item);
        controller.remove(item);
      }

      final secondPageHoldCompleter = server.hold(1, attempt: 2);
      final lastPageHoldCompleter = server.hold(2, attempt: 2);
      unawaited(controller.refresh());
      await tester.idle();
      await drain(tester, frames: 4);
      remove(0);
      await release(tester, [secondPageHoldCompleter]);
      // More than a page's worth, so the pages read again for the 2 boundaries overlap.
      _range(1, 4).forEach(remove);
      await release(tester, [lastPageHoldCompleter]);

      check(await _allShownItems(tester, scrollController))
          .deepEquals(server.store.take(_pageSize * 3));
    });
  });
}

/// Removes row 1, which the server already dropped.
typedef _RowRemover = ValueSetter<ListSmithController<int>>;

final _rowRemovers = <String, _RowRemover>{
  'its save already answered': (controller) => controller.remove(1),
  'its save still out': (controller) =>
      unawaited(controller.removeAsync(1, commit: Completer<void>().future)),
};

/// Picks one of the server's `withSignal` fetchers.
typedef _SignalFetcherGetter = PageFetcher<int> Function(FakeServer<int> server);

final _signalFetchers = <String, _SignalFetcherGetter>{
  'paged by number with a hasMore flag': (server) => server.hasMoreSignalFetcher,
  'with an offset as the cursor': (server) => server.offsetCursorFetcher,
};

const _pageSize = 3;

/// Tall enough that pages 0 to 2 load at mount and page 3 waits for a scroll.
const _rowHeight = 300.0;

/// Short enough that every row fits, so the list asks for each page as soon as the one before lands.
const _shortRowHeight = 20.0;

Future<ListSmithController<int>> _pumpList(
  WidgetTester tester, {
  required PageFetcher<int> fetchPage,
  required ScrollController scrollController,
  ListSmithController<int>? controller,
  double rowHeight = _rowHeight,
  bool isTransitionOn = false,
  PaginationEndPolicy endPolicy = const StopOnEmptyPagesPolicy(),
  Refresh refresh = const PullToRefresh(),
  Search<int> search = const NoSearch(),
  String query = '',
}) async {
  final handle = controller ?? ListSmithController<int>();
  await pumpListSmith(
    tester,
    ListSmith<int>.async(
      fetchPage: fetchPage,
      pageSize: _pageSize,
      itemIdGetter: (item) => item,
      editTransition: isTransitionOn
          ? EditTransition(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) =>
                  SizeTransition(sizeFactor: animation, alignment: .topStart, child: child),
            )
          : const NoEditTransition(),
      endPolicy: endPolicy,
      refresh: refresh,
      search: search,
      query: query,
      searchDebounce: const Duration(milliseconds: 20),
      scroll: ListScrollConfig(controller: scrollController),
      controller: handle,
      itemBuilder: (_, item, _) => SizedBox(height: rowHeight, child: Text('item $item')),
    ),
  );
  await drain(tester, frames: 12);

  return handle;
}

/// Search over [server]'s even rows by offset, noting each page it's asked for in [pageIndexes].
SearchPageFetcher<int> _evenRowsFetcher(FakeServer<int> server, List<int> pageIndexes) =>
    SearchPageFetcher((request) async {
      pageIndexes.add(request.pageIndex);

      return server.store
          .where((item) => item.isEven)
          .skip(request.pageIndex * request.pageSize)
          .take(request.pageSize);
    });

Future<List<int>> _allShownItems(WidgetTester tester, ScrollController scrollController) async =>
    (await allShownTexts(tester, scrollController, 'item ')).map(int.parse).toList(growable: false);

List<int> _range(int from, int to) => List.generate(to - from + 1, (index) => from + index);

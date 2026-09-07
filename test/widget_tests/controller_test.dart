// A test-local observer double shares the file with the scenarios that drive it.
// ignore_for_file: prefer-match-file-name

import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

import '../support/support.dart';

void main() {
  feature('ListSmith.async ListSmithController', () {
    // Each page yields one item stamped `page * 1000 + attempt`, so a test can tell a refetched
    // page from its first load. `attempts` records how many times each index was fetched.
    ({PageFetcher<int> fetchPage, Map<int, int> attempts}) valuedFetcher() {
      final attempts = <int, int>{};
      final fetchPage = PageFetcher<int>((request) async {
        final attempt = attempts[request.pageIndex] = (attempts[request.pageIndex] ?? 0) + 1;

        return [request.pageIndex * 1000 + attempt];
      });

      return (fetchPage: fetchPage, attempts: attempts);
    }

    Future<void> pumpList(
      WidgetTester tester, {
      required PageFetcher<int> fetchPage,
      required ListSmithController? controller,
      int pageCount = 1,
      Refresh refresh = const PullToRefresh(),
      Search<int> search = const NoSearch(),
      String query = '',
      ListSmithObserver? observer,
    }) => pumpListSmith(
      tester,
      ListSmith.async(
        fetchPage: fetchPage,
        endPolicy: FixedPageCountPolicy(pageCount: pageCount),
        refresh: refresh,
        search: search,
        query: query,
        searchDebounce: const Duration(milliseconds: 20),
        controller: controller,
        observer: observer,
        itemBuilder: (_, item, _) => Text('item $item'),
      ),
    );

    scenarioWidgets('refresh() reloads the list without a pull', (tester) async {
      final fetcher = valuedFetcher();
      final controller = ListSmithController();

      await pumpList(tester, fetchPage: fetcher.fetchPage, controller: controller);
      await drain(tester);
      check(fetcher.attempts).deepEquals({0: 1});

      await controller.refresh();
      await drain(tester);

      // Page 0 was fetched again, and the list now shows its fresh stamp.
      check(fetcher.attempts).deepEquals({0: 2});
      check(find.text('item 2').evaluate()).length.equals(1);
      check(find.text('item 1').evaluate()).length.equals(0);
    });

    scenarioWidgets('refresh() runs the configured reload, so it keeps depth', (tester) async {
      final fetcher = valuedFetcher();
      final controller = ListSmithController();

      await pumpList(
        tester,
        fetchPage: fetcher.fetchPage,
        controller: controller,
        pageCount: 3,
        refresh: const PullToRefresh(reload: ReloadToCurrentDepth(concurrency: null)),
      );
      await drain(tester, frames: 12);
      check(fetcher.attempts).deepEquals({0: 1, 1: 1, 2: 1});

      await controller.refresh();
      await drain(tester);

      // Every loaded page was refetched, not just the first: this is the pull's own path.
      check(fetcher.attempts).deepEquals({0: 2, 1: 2, 2: 2});
    });

    scenarioWidgets('refresh() works on a list with no pull gesture', (tester) async {
      final fetcher = valuedFetcher();
      final controller = ListSmithController();

      await pumpList(
        tester,
        fetchPage: fetcher.fetchPage,
        controller: controller,
        refresh: const NoRefresh(),
      );
      await drain(tester);

      await controller.refresh();
      await drain(tester);

      check(fetcher.attempts).deepEquals({0: 2});
    });

    scenarioWidgets('a second refresh joins the one in flight instead of rivalling it', (
      tester,
    ) async {
      final fetcher = valuedFetcher();
      final controller = ListSmithController();
      final observer = RecordingListSmithObserver();

      await pumpList(
        tester,
        fetchPage: fetcher.fetchPage,
        controller: controller,
        pageCount: 3,
        refresh: const PullToRefresh(reload: ReloadToCurrentDepth()),
        observer: observer,
      );
      await drain(tester, frames: 12);

      await [controller.refresh(), controller.refresh()].wait;
      await drain(tester);

      // One reload ran and one event fired: the second call rode the first.
      check(observer.events.where((event) => event == 'reload(refresh)')).length.equals(1);
      check(fetcher.attempts).deepEquals({0: 2, 1: 2, 2: 2});
    });

    scenarioWidgets('a second refresh joins under the default reload too', (tester) async {
      final fetcher = valuedFetcher();
      final controller = ListSmithController();
      final observer = RecordingListSmithObserver();

      await pumpList(
        tester,
        fetchPage: fetcher.fetchPage,
        controller: controller,
        observer: observer,
      );
      await drain(tester);

      // ResetToFirstPage resets the stream at once. The run's own reset must not read as "moved on".
      await [controller.refresh(), controller.refresh()].wait;
      await drain(tester);

      check(observer.events.where((event) => event == 'reload(refresh)')).length.equals(1);
      check(fetcher.attempts).deepEquals({0: 2});
    });

    scenarioWidgets('a refresh() re-entered from the reload event joins the one starting', (
      tester,
    ) async {
      final fetcher = valuedFetcher();
      final controller = ListSmithController();
      final observer = _ReentrantObserver(controller);

      await pumpList(
        tester,
        fetchPage: fetcher.fetchPage,
        controller: controller,
        pageCount: 3,
        refresh: const PullToRefresh(reload: ReloadToCurrentDepth(concurrency: null)),
        observer: observer,
      );
      await drain(tester, frames: 12);

      await controller.refresh();
      await drain(tester);

      check(observer.fired).equals(1);
      check(fetcher.attempts).deepEquals({0: 2, 1: 2, 2: 2});
    });

    scenarioWidgets('a refresh() right after one finished runs its own', (tester) async {
      final fetcher = valuedFetcher();
      final controller = ListSmithController();

      await pumpList(
        tester,
        fetchPage: fetcher.fetchPage,
        controller: controller,
        pageCount: 3,
        refresh: const PullToRefresh(reload: ReloadToCurrentDepth(concurrency: null)),
      );
      await drain(tester, frames: 12);

      // No frame between them: the second call runs in the first one's continuation.
      await controller.refresh();
      await controller.refresh();
      await drain(tester);

      check(fetcher.attempts).deepEquals({0: 3, 1: 3, 2: 3});
    });

    scenarioWidgets('refresh() while searching reloads the search, not the normal list', (
      tester,
    ) async {
      final normal = valuedFetcher();
      final searchAttempts = <int, int>{};
      final controller = ListSmithController();
      final search = AsyncSearch<int>(
        fetchPage: SearchPageFetcher((request) async {
          searchAttempts[request.pageIndex] = (searchAttempts[request.pageIndex] ?? 0) + 1;

          return [request.pageIndex];
        }),
      );

      await pumpList(tester, fetchPage: normal.fetchPage, controller: controller, search: search);
      await drain(tester);
      check(normal.attempts).deepEquals({0: 1});

      await pumpList(
        tester,
        fetchPage: normal.fetchPage,
        controller: controller,
        search: search,
        query: 'ab',
      );
      await settle(tester);
      check(searchAttempts).deepEquals({0: 1});

      await controller.refresh();
      await drain(tester);

      // The search stream reloaded. The normal fetcher was left alone.
      check(searchAttempts).deepEquals({0: 2});
      check(normal.attempts).deepEquals({0: 1});
    });

    scenarioWidgets('refresh() before any list attaches the controller asserts', (tester) async {
      final controller = ListSmithController();

      check(controller.refresh).throws<AssertionError>();
    });

    scenarioWidgets('refresh() after the list is gone is inert', (tester) async {
      final fetcher = valuedFetcher();
      final controller = ListSmithController();

      await pumpList(tester, fetchPage: fetcher.fetchPage, controller: controller);
      await drain(tester);
      await pumpListSmith(tester, const SizedBox.shrink());

      await controller.refresh();
      await drain(tester);

      check(fetcher.attempts).deepEquals({0: 1});
    });

    scenarioOutlineWidgets(
      'invalidate() re-reads every loaded page in place, whatever the pull does',
      examples: const {
        'no pull gesture': NoRefresh(),
        'pull resets to the first page': PullToRefresh(),
        'pull keeps depth': PullToRefresh(reload: ReloadToCurrentDepth(concurrency: null)),
      },
      outline: (tester, refresh) async {
        final hold = Completer<void>();
        final fetcher = _heldFetcher(hold, holdAttempt: 2);
        final controller = ListSmithController();

        await pumpList(
          tester,
          fetchPage: fetcher.fetchPage,
          controller: controller,
          pageCount: 3,
          refresh: refresh,
        );
        await drain(tester, frames: 12);

        final invalidate = controller.invalidate();
        await drain(tester);
        // The old rows stay on screen until the re-read commits: nobody's place is lost.
        check(find.text('item 1').evaluate()).length.equals(1);

        hold.complete();
        await tester.idle();
        await drain(tester, frames: 12);
        await invalidate;

        check(fetcher.attempts).deepEquals({0: 2, 1: 2, 2: 2});
        check(find.text('item 2002').evaluate()).length.equals(1);
      },
    );

    scenarioWidgets('reset() clears the list and starts over, under a depth-keeping pull too', (
      tester,
    ) async {
      final fetcher = valuedFetcher();
      final controller = ListSmithController();

      await pumpList(
        tester,
        fetchPage: fetcher.fetchPage,
        controller: controller,
        pageCount: 3,
        refresh: const PullToRefresh(reload: ReloadToCurrentDepth(concurrency: null)),
      );
      await drain(tester, frames: 12);

      await controller.reset();
      await tester.pump();
      // Gone at once, then paged in again from the top.
      check(find.textContaining('item ').evaluate()).isEmpty();
      await drain(tester, frames: 12);

      check(find.text('item 2').evaluate()).length.equals(1);
      check(find.text('item 1').evaluate()).length.equals(0);
    });

    scenarioWidgets('invalidate() and reset() before any list attached are no-ops', (tester) async {
      final controller = ListSmithController();

      await controller.invalidate();
      await controller.reset();
      check(controller.refresh).throws<AssertionError>();
    });

    scenarioWidgets('an invalidate() meeting a live one runs again, so a write mid-read lands', (
      tester,
    ) async {
      final hold = Completer<void>();
      final store = {0: 10, 1: 20, 2: 30};
      final attempts = <int, int>{};
      final fetchPage = PageFetcher<int>((request) async {
        final attempt = attempts[request.pageIndex] = (attempts[request.pageIndex] ?? 0) + 1;
        // The re-read stalls on page 1.
        if (request.pageIndex == 1 && attempt == 2) await hold.future;

        return [store[request.pageIndex]!];
      });
      final controller = ListSmithController();
      final observer = RecordingListSmithObserver();

      await pumpList(
        tester,
        fetchPage: fetchPage,
        controller: controller,
        pageCount: 3,
        refresh: const NoRefresh(),
        observer: observer,
      );
      await drain(tester, frames: 12);

      final first = controller.invalidate(); // reads page 0 at once, then stalls
      await drain(tester);
      store[0] = 11; // a write lands on a page the run already read
      final second = controller.invalidate();
      await drain(tester);

      hold.complete();
      await tester.idle();
      await drain(tester, frames: 12);
      await (first, second).wait;

      check(find.text('item 11').evaluate()).length.equals(1);
      check(observer.events.where((event) => event == 'reload(invalidated)')).length.equals(2);
    });

    scenarioWidgets('a reset() during a depth re-read wins, and that re-read commits nothing', (
      tester,
    ) async {
      final hold = Completer<void>();
      final fetcher = _heldFetcher(hold, holdAttempt: 2);
      final controller = ListSmithController();

      await pumpList(tester, fetchPage: fetcher.fetchPage, controller: controller, pageCount: 3);
      await drain(tester, frames: 12);

      final invalidate = controller.invalidate(); // every page held
      await drain(tester);
      await controller.reset();
      await drain(tester, frames: 12);
      check(find.text('item 3').evaluate()).length.equals(1); // the reset's stream is in

      hold.complete();
      await tester.idle();
      await drain(tester, frames: 12);
      await invalidate;

      check(find.text('item 3').evaluate()).length.equals(1);
      check(find.text('item 2').evaluate()).length.equals(0);
    });

    scenarioWidgets('an invalidate() right after a cut-in reset() is not lost', (tester) async {
      final hold = Completer<void>();
      final fetcher = _heldFetcher(hold, holdAttempt: 2);
      final controller = ListSmithController();
      final observer = RecordingListSmithObserver();

      await pumpList(
        tester,
        fetchPage: fetcher.fetchPage,
        controller: controller,
        pageCount: 3,
        observer: observer,
      );
      await drain(tester, frames: 12);

      final first = controller.invalidate(); // held, about to be superseded
      await drain(tester);
      await controller.reset();
      final second = controller.invalidate(); // must not join a run that will commit nothing
      await drain(tester, frames: 12);

      hold.complete();
      await tester.idle();
      await drain(tester, frames: 12);
      await (first, second).wait;

      // Three reloads started: the held one, the reset, and the invalidate that refused to join.
      check(observer.events.where((event) => event == 'reload(invalidated)')).length.equals(3);
      check(find.text('item 2').evaluate()).length.equals(0);
    });

    scenarioWidgets('a refresh() joining a live invalidate() gets its refresh afterwards', (
      tester,
    ) async {
      final hold = Completer<void>();
      final fetcher = _heldFetcher(hold, holdAttempt: 2);
      final controller = ListSmithController();
      final observer = RecordingListSmithObserver();

      await pumpList(
        tester,
        fetchPage: fetcher.fetchPage,
        controller: controller,
        pageCount: 3,
        observer: observer,
      );
      await drain(tester, frames: 12);

      final invalidate = controller.invalidate();
      await drain(tester);
      final refresh = controller.refresh(); // fresh data wanted, a store re-read won't do
      await drain(tester);

      hold.complete();
      await tester.idle();
      await drain(tester, frames: 12);
      await (invalidate, refresh).wait;

      check(observer.events.where((event) => event.startsWith('reload(')))
          .deepEquals(['reload(invalidated)', 'reload(refresh)']);
    });

    scenarioWidgets(
      'a refresh pending behind a live re-read is not downgraded by a later invalidate',
      (tester) async {
        final hold = Completer<void>();
        final fetcher = _heldFetcher(hold, holdAttempt: 2);
        final controller = ListSmithController();
        final observer = RecordingListSmithObserver();

        await pumpList(
          tester,
          fetchPage: fetcher.fetchPage,
          controller: controller,
          pageCount: 3,
          observer: observer,
        );
        await drain(tester, frames: 12);

        final invalidate = controller.invalidate();
        await drain(tester);
        final refresh = controller.refresh();
        final again = controller.invalidate(); // both pending: one rerun, and it is the refresh
        await drain(tester);

        hold.complete();
        await tester.idle();
        await drain(tester, frames: 12);
        await (invalidate, refresh, again).wait;

        check(observer.events.where((event) => event.startsWith('reload(')))
            .deepEquals(['reload(invalidated)', 'reload(refresh)']);
      },
    );

    scenarioWidgets('swapping the controller moves the handle to the new one', (tester) async {
      final fetcher = valuedFetcher();
      final first = ListSmithController();
      final second = ListSmithController();

      await pumpList(tester, fetchPage: fetcher.fetchPage, controller: first);
      await drain(tester);
      await pumpList(tester, fetchPage: fetcher.fetchPage, controller: second);
      await drain(tester);

      await first.refresh();
      await drain(tester);
      check(fetcher.attempts).deepEquals({0: 1});

      await second.refresh();
      await drain(tester);
      check(fetcher.attempts).deepEquals({0: 2});
    });
  });
}

/// A stamped fetcher whose [holdAttempt]-th fetch of every page waits on [hold].
({PageFetcher<int> fetchPage, Map<int, int> attempts}) _heldFetcher(
  Completer<void> hold, {
  required int holdAttempt,
}) {
  final attempts = <int, int>{};
  final fetchPage = PageFetcher<int>((request) async {
    final attempt = attempts[request.pageIndex] = (attempts[request.pageIndex] ?? 0) + 1;
    if (attempt == holdAttempt) await hold.future;

    return [request.pageIndex * 1000 + attempt];
  });

  return (fetchPage: fetchPage, attempts: attempts);
}

/// Calls `refresh()` back from the reload event, once, as a consumer chaining work off it might.
final class _ReentrantObserver extends ListSmithObserver {
  final ListSmithController controller;
  var fired = 0;

  new(this.controller);

  @override
  void onReload(FetchTrigger trigger) {
    fired++;
    if (fired == 1) unawaited(controller.refresh());
  }
}

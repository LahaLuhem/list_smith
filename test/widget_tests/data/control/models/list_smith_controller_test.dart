// Test-local fixtures share the file with the scenarios that use them.
// ignore_for_file: prefer-match-file-name

import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

import '../../../../support/support.dart';

void main() {
  feature('ListSmith.async ListSmithController', () {
    // Each page yields one item stamped `page * 1000 + attempt`, so a test can tell a refetched page
    // from its 1st load. `attempts` records how many times each index was fetched.
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
        itemIdGetter: (item) => item,
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

    // Labelled rows, so a draft and its saved answer look different.
    Future<void> pumpRows(
      WidgetTester tester, {
      required ListSmithController<_Row> controller,
      List<_Row> serverRows = const [],
      EditTransition editTransition = const NoEditTransition(),
      bool isMotionReduced = false,
    }) => pumpListSmith(
      tester,
      MediaQuery(
        data: MediaQueryData(disableAnimations: isMotionReduced),
        child: ListSmith<_Row>.async(
          fetchPage: PageFetcher((_) async => serverRows),
          itemIdGetter: (row) => row.id,
          endPolicy: const FixedPageCountPolicy(pageCount: 1),
          editTransition: editTransition,
          controller: controller,
          itemBuilder: (_, row, _) => Text('row ${row.id} ${row.label}'),
        ),
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

      // Every loaded page was refetched, not just the 1st: this is the pull's own path.
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

      // No frame between them: the 2nd call runs in the 1st one's continuation.
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

    scenarioWidgets('search() before any list attaches the controller asserts', (tester) async {
      final controller = ListSmithController<int>();

      check(() => controller.search('1')).throws<AssertionError>();
    });

    scenarioWidgets('search() with no query asserts', (tester) async {
      final controller = ListSmithController();
      await pumpList(
        tester,
        fetchPage: valuedFetcher().fetchPage,
        controller: controller,
        search: AsyncSearch(
          fetchPage: pagedSearchFetcher(const [
            [1],
          ]),
        ),
      );
      await drain(tester);

      check(() => controller.search('  ')).throws<AssertionError>();
    });

    scenarioWidgets('refresh() and search() after the list is gone are inert', (tester) async {
      final fetcher = valuedFetcher();
      final controller = ListSmithController();

      await pumpList(tester, fetchPage: fetcher.fetchPage, controller: controller);
      await drain(tester);
      await pumpListSmith(tester, const SizedBox.shrink());

      await controller.refresh();
      await controller.search('1');
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
        final holdCompleter = Completer<void>();
        final fetcher = _heldFetcher(holdCompleter, holdAttempt: 2);
        final controller = ListSmithController();

        await pumpList(
          tester,
          fetchPage: fetcher.fetchPage,
          controller: controller,
          pageCount: 3,
          refresh: refresh,
        );
        await drain(tester, frames: 12);

        final invalidateFuture = controller.invalidate();
        await drain(tester);
        // The old rows stay on screen until the re-read commits: nobody's place is lost.
        check(find.text('item 1').evaluate()).length.equals(1);

        holdCompleter.complete();
        await tester.idle();
        await drain(tester, frames: 12);
        await invalidateFuture;

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
      check(find.text('item 1').evaluate()).isEmpty;
      await drain(tester, frames: 12);

      check(find.text('item 2').evaluate()).length.equals(1);
      check(find.text('item 1').evaluate()).length.equals(0);
    });

    scenarioWidgets(
      'refresh(), invalidate(), reset(), endSearch() and edits before any list attached are no-ops',
      (tester) async {
        final controller = ListSmithController<int>();

        await controller.refresh();
        await controller.invalidate();
        await controller.reset();
        await controller.endSearch();
        controller
          ..upsert(1)
          ..remove(1);
      },
    );

    scenarioWidgets('an async edit with no list attached still reports a failed save', (
      tester,
    ) async {
      final controller = ListSmithController<int>();
      final reportedExceptions = <Exception>[];

      await controller.upsertAsync(
        1,
        commit: Future.syncValue(1),
        onFailure: reportedExceptions.add,
      );
      await controller.removeAsync(
        1,
        commit: Future.error(Exception('delete failed')),
        onFailure: reportedExceptions.add,
      );

      check(reportedExceptions).length.equals(1);
    });

    scenarioOutlineWidgets<({bool wasListBuilt, EditTransition editTransition})>(
      'a save made with no list attached shows in the next one, its draft then its answer',
      examples: const {
        'before any list was built': (wasListBuilt: false, editTransition: NoEditTransition()),
        'after the list went': (wasListBuilt: true, editTransition: NoEditTransition()),
        'under an edit transition': (
          wasListBuilt: false,
          editTransition: EditTransition(
            duration: Duration(milliseconds: 300),
            transitionBuilder: AnimatedSwitcher.defaultTransitionBuilder,
          ),
        ),
      },
      outline: (tester, example) async {
        final controller = ListSmithController<_Row>();
        if (example.wasListBuilt) {
          await pumpRows(tester, controller: controller);
          await drain(tester);
          await pumpListSmith(tester, const SizedBox.shrink());
        }
        final saveCompleter = Completer<_Row>();

        final savedFuture = controller.upsertAsync((
          id: 9,
          label: 'mine',
        ), commit: saveCompleter.future);
        await pumpRows(tester, controller: controller, editTransition: example.editTransition);
        await drain(tester);
        // Page 0 came without it, so this is the draft.
        check(find.text('row 9 mine').evaluate()).length.equals(1);

        saveCompleter.complete((id: 9, label: 'saved'));
        await savedFuture;
        await drain(tester);

        check(find.text('row 9 saved').evaluate()).length.equals(1);
      },
    );

    scenarioOutlineWidgets<({bool isTakenOver, Object failure})>(
      'a held save that fails reaches the app once, its draft gone',
      examples: {
        'an Error, with no list to take it': (
          isTakenOver: false,
          failure: StateError('a bug in the save'),
        ),
        'an Exception, a list taking it': (isTakenOver: true, failure: Exception('save failed')),
        'an Error, a list taking it': (isTakenOver: true, failure: StateError('a bug in the save')),
      },
      outline: (tester, example) async {
        final controller = ListSmithController<_Row>();
        final saveCompleter = Completer<_Row>();
        final reportedExceptions = <Exception>[];
        final savedFuture = controller.upsertAsync(
          (id: 9, label: 'mine'),
          commit: saveCompleter.future,
          onFailure: reportedExceptions.add,
        );
        if (example.isTakenOver) {
          await pumpRows(tester, controller: controller);
          await drain(tester);
          check(find.text('row 9 mine').evaluate()).length.equals(1);
        }

        saveCompleter.completeError(example.failure);
        final callerFailure = await savedFuture.then<Object?>(
          (_) => null,
          onError: (Object error) => error,
        );
        await drain(tester);

        check([...reportedExceptions, ?callerFailure]).deepEquals([example.failure]);
        check(find.text('row 9 mine').evaluate()).isEmpty;
      },
    );

    scenarioWidgets('a delete made with no list attached hides its row in the next one', (
      tester,
    ) async {
      final controller = ListSmithController<_Row>();

      unawaited(controller.removeAsync((id: 1, label: 'a'), commit: Completer<void>().future));
      // The server still has it, since the delete is out.
      await pumpRows(tester, controller: controller, serverRows: [(id: 1, label: 'a')]);
      await drain(tester);

      check(find.text('row 1 a').evaluate()).isEmpty;
    });

    scenarioWidgets('reset() with no list attached drops a held save, which still finishes', (
      tester,
    ) async {
      final controller = ListSmithController<_Row>();
      final saveCompleter = Completer<_Row>();
      final reportedExceptions = <Exception>[];
      final savedFuture = controller.upsertAsync(
        (id: 9, label: 'mine'),
        commit: saveCompleter.future,
        onFailure: reportedExceptions.add,
      );

      await controller.reset();
      await pumpRows(tester, controller: controller);
      await drain(tester);
      // Like a logout, so the next account's list never shows it.
      check(find.text('row 9 mine').evaluate()).isEmpty;

      saveCompleter.completeError(Exception('save failed'));
      await savedFuture;
      check(reportedExceptions).length.equals(1);
    });

    scenarioWidgets('an invalidate() meeting a live one runs again, so a write mid-read lands', (
      tester,
    ) async {
      final holdCompleter = Completer<void>();
      final store = {0: 10, 1: 20, 2: 30};
      final attempts = <int, int>{};
      final fetchPage = PageFetcher<int>((request) async {
        final attempt = attempts[request.pageIndex] = (attempts[request.pageIndex] ?? 0) + 1;
        // The re-read stalls on page 1.
        if (request.pageIndex == 1 && attempt == 2) await holdCompleter.future;

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

      final firstReloadFuture = controller.invalidate(); // reads page 0 at once, then stalls
      await drain(tester);
      store[0] = 11; // a write lands on a page the run already read
      final secondReloadFuture = controller.invalidate();
      await drain(tester);

      holdCompleter.complete();
      await tester.idle();
      await drain(tester, frames: 12);
      await (firstReloadFuture, secondReloadFuture).wait;

      check(find.text('item 11').evaluate()).length.equals(1);
      check(observer.events.where((event) => event == 'reload(invalidated)')).length.equals(2);
    });

    scenarioWidgets('a reset() during a depth re-read wins, and that re-read commits nothing', (
      tester,
    ) async {
      final holdCompleter = Completer<void>();
      final fetcher = _heldFetcher(holdCompleter, holdAttempt: 2);
      final controller = ListSmithController();

      await pumpList(tester, fetchPage: fetcher.fetchPage, controller: controller, pageCount: 3);
      await drain(tester, frames: 12);

      final invalidateFuture = controller.invalidate(); // every page held
      await drain(tester);
      await controller.reset();
      await drain(tester, frames: 12);
      check(find.text('item 3').evaluate()).length.equals(1); // the reset's stream is in

      holdCompleter.complete();
      await tester.idle();
      await drain(tester, frames: 12);
      await invalidateFuture;

      check(find.text('item 3').evaluate()).length.equals(1);
      check(find.text('item 2').evaluate()).length.equals(0);
    });

    scenarioWidgets('an invalidate() right after a cut-in reset() is not lost', (tester) async {
      final holdCompleter = Completer<void>();
      final fetcher = _heldFetcher(holdCompleter, holdAttempt: 2);
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

      final firstReloadFuture = controller.invalidate(); // held, about to be superseded
      await drain(tester);
      await controller.reset();
      final secondReloadFuture = controller
          .invalidate(); // must not join a run that will commit nothing
      await drain(tester, frames: 12);

      holdCompleter.complete();
      await tester.idle();
      await drain(tester, frames: 12);
      await (firstReloadFuture, secondReloadFuture).wait;

      // 3 reloads started: the held one, the reset, and the invalidate that refused to join.
      check(observer.events.where((event) => event == 'reload(invalidated)')).length.equals(3);
      check(find.text('item 2').evaluate()).length.equals(0);
    });

    scenarioWidgets('a refresh() joining a live invalidate() gets its refresh afterwards', (
      tester,
    ) async {
      final holdCompleter = Completer<void>();
      final fetcher = _heldFetcher(holdCompleter, holdAttempt: 2);
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

      final invalidateFuture = controller.invalidate();
      await drain(tester);
      final refreshFuture = controller.refresh(); // fresh data wanted, a store re-read won't do
      await drain(tester);

      holdCompleter.complete();
      await tester.idle();
      await drain(tester, frames: 12);
      await (invalidateFuture, refreshFuture).wait;

      check(observer.events.where((event) => event.startsWith('reload(')))
          .deepEquals(['reload(invalidated)', 'reload(refresh)']);
    });

    scenarioWidgets(
      'a refresh pending behind a live re-read is not downgraded by a later invalidate',
      (tester) async {
        final holdCompleter = Completer<void>();
        final fetcher = _heldFetcher(holdCompleter, holdAttempt: 2);
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

        final invalidateFuture = controller.invalidate();
        await drain(tester);
        final refreshFuture = controller.refresh();
        final secondInvalidateFuture = controller
            .invalidate(); // both pending: one rerun, and it is the refresh
        await drain(tester);

        holdCompleter.complete();
        await tester.idle();
        await drain(tester, frames: 12);
        await (invalidateFuture, refreshFuture, secondInvalidateFuture).wait;

        check(observer.events.where((event) => event.startsWith('reload(')))
            .deepEquals(['reload(invalidated)', 'reload(refresh)']);
      },
    );

    scenarioWidgets('swapping the controller moves the handle to the new one', (tester) async {
      final fetcher = valuedFetcher();
      final firstController = ListSmithController();
      final secondController = ListSmithController();

      await pumpList(tester, fetchPage: fetcher.fetchPage, controller: firstController);
      await drain(tester);
      await pumpList(tester, fetchPage: fetcher.fetchPage, controller: secondController);
      await drain(tester);

      await firstController.refresh();
      await drain(tester);
      check(fetcher.attempts).deepEquals({0: 1});

      await secondController.refresh();
      await drain(tester);
      check(fetcher.attempts).deepEquals({0: 2});
    });

    scenarioWidgets('turning on reduce motion keeps the controller driving its list', (
      tester,
    ) async {
      const editTransition = EditTransition(
        duration: Duration(milliseconds: 300),
        transitionBuilder: AnimatedSwitcher.defaultTransitionBuilder,
      );
      final controller = ListSmithController<_Row>();
      await pumpRows(tester, controller: controller, editTransition: editTransition);
      await drain(tester);
      // Its animation reads MediaQuery, so the list now depends on it.
      controller.upsert((id: 1, label: 'a'));
      await drain(tester);

      await pumpRows(
        tester,
        controller: controller,
        editTransition: editTransition,
        isMotionReduced: true,
      );
      controller.upsert((id: 2, label: 'b'));
      await drain(tester);

      check(find.text('row 2 b').evaluate()).length.equals(1);
    });
  });
}

typedef _Row = ({int id, String label});

/// A stamped fetcher whose [holdAttempt]-th fetch of every page waits on [holdCompleter].
({PageFetcher<int> fetchPage, Map<int, int> attempts}) _heldFetcher(
  Completer<void> holdCompleter, {
  required int holdAttempt,
}) {
  final attempts = <int, int>{};
  final fetchPage = PageFetcher<int>((request) async {
    final attempt = attempts[request.pageIndex] = (attempts[request.pageIndex] ?? 0) + 1;
    if (attempt == holdAttempt) await holdCompleter.future;

    return [request.pageIndex * 1000 + attempt];
  });

  return (fetchPage: fetchPage, attempts: attempts);
}

/// Calls `refresh()` back from the reload event, once, as a consumer chaining work off it might.
final class _ReentrantObserver(final ListSmithController controller) extends ListSmithObserver {
  var fired = 0;

  @override
  void onReload(FetchTrigger trigger) {
    fired++;
    if (fired == 1) unawaited(controller.refresh());
  }
}

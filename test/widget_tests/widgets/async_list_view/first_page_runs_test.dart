import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

import '../../../support/support.dart';

void main() {
  feature('ListSmith.async 1st-page loads', () {
    Future<void> pumpList(
      WidgetTester tester,
      FakeServer<int> server, {
      ListSmithController<int>? controller,
      ListSmithObserver? observer,
      Refresh refresh = const PullToRefresh(),
    }) => pumpListSmith(
      tester,
      ListSmith.async(
        fetchPage: server.offsetLateFetcher,
        itemIdGetter: (item) => item,
        pageSize: 3,
        endPolicy: const FixedPageCountPolicy(pageCount: 1),
        refresh: refresh,
        controller: controller,
        observer: observer,
        itemBuilder: (_, item, _) => SizedBox(height: 50, child: Text('item $item')),
      ),
    );

    scenarioOutlineWidgets<List<AsyncValueSetter<ListSmithController<int>>>>(
      'restarts from code a frame apart during the 1st load still land a page',
      examples: {
        'refresh() twice': [
          (controller) => controller.refresh(),
          (controller) => controller.refresh(),
        ],
        'refresh() then reset()': [
          (controller) => controller.refresh(),
          (controller) => controller.reset(),
        ],
        'invalidate() right after mount': [(controller) => controller.invalidate()],
      },
      outline: (tester, restarts) async {
        final server = FakeServer<int>([1, 2, 3]);
        final firstLoadHoldCompleter = server.hold(0, attempt: 1);
        final controller = ListSmithController<int>();
        await pumpList(tester, server, controller: controller);

        for (final restart in restarts) {
          unawaited(restart(controller));
          await tester.pump();
        }
        await release(tester, [firstLoadHoldCompleter]);

        check(find.text('item 1').evaluate()).length.equals(1);
      },
    );

    scenarioWidgets('a refresh tapped twice while its page loads sends 1 request', (tester) async {
      final server = FakeServer<int>([1, 2, 3]);
      final controller = ListSmithController<int>();
      await pumpList(tester, server, controller: controller);
      await drain(tester);
      final holdCompleter = server.hold(0, attempt: 2);

      unawaited(controller.refresh());
      await drain(tester, frames: 9); // a double tap is many frames apart
      unawaited(controller.refresh());
      await release(tester, [holdCompleter]);

      check(server.attempts[0]).equals(2);
    });

    scenarioWidgets('a local write during the 1st load is read once, after it lands', (
      tester,
    ) async {
      final server = FakeServer<int>([1, 2, 3]);
      final firstLoadHoldCompleter = server.hold(0, attempt: 1);
      final controller = ListSmithController<int>();
      await pumpList(tester, server, controller: controller);
      await drain(tester);

      unawaited(controller.invalidate());
      await drain(tester);
      unawaited(controller.invalidate());
      await drain(tester);
      // The 1st load's answer may predate the write, so the re-read waits for it.
      check(server.attempts[0]).equals(1);
      await release(tester, [firstLoadHoldCompleter]);

      check(server.requests.map((request) => request.trigger))
          .deepEquals([FetchTrigger.initialLoad, FetchTrigger.invalidated]);
    });

    scenarioOutlineWidgets<({AsyncValueSetter<ListSmithController<int>> callVerb, bool isFailing})>(
      'a verb from code completes once its fresh page has landed or failed',
      examples: {
        'refresh(), landing': (callVerb: (controller) => controller.refresh(), isFailing: false),
        'invalidate(), landing': (
          callVerb: (controller) => controller.invalidate(),
          isFailing: false,
        ),
        'reset(), landing': (callVerb: (controller) => controller.reset(), isFailing: false),
        'reset(), failing': (callVerb: (controller) => controller.reset(), isFailing: true),
      },
      outline: (tester, example) async {
        final server = FakeServer<int>([1, 2, 3]);
        if (example.isFailing) server.failing.add((0, 2));
        final controller = ListSmithController<int>();
        await pumpList(tester, server, controller: controller);
        await drain(tester);
        final holdCompleter = server.hold(0, attempt: 2);

        var isDone = false;
        unawaited(example.callVerb(controller).then((_) => isDone = true));
        await drain(tester);
        check(server.attempts[0]).equals(2); // the fresh page is out, and held
        check(isDone).isFalse;
        await release(tester, [holdCompleter]);

        check(isDone).isTrue;
      },
    );

    scenarioOutlineWidgets<
      ({
        AsyncValueSetter<ListSmithController<int>>? liveVerb,
        Future<Exception?> Function(ListSmithController<int>) callVerb,
        Set<int> failingAttempts,
        int askAttempt,
      })
    >(
      'refresh() and invalidate() complete with what the run doing their ask threw, or null',
      examples: {
        'refresh() on the error screen, landing': (
          liveVerb: null,
          callVerb: (controller) => controller.refresh(),
          failingAttempts: {1},
          askAttempt: 2,
        ),
        'refresh() on the error screen, failing': (
          liveVerb: null,
          callVerb: (controller) => controller.refresh(),
          failingAttempts: {1, 2},
          askAttempt: 2,
        ),
        'refresh() joining a live refresh()': (
          liveVerb: (controller) => controller.refresh(),
          callVerb: (controller) => controller.refresh(),
          failingAttempts: {2},
          askAttempt: 2,
        ),
        'refresh() booked behind a live invalidate()': (
          liveVerb: (controller) => controller.invalidate(),
          callVerb: (controller) => controller.refresh(),
          failingAttempts: {3},
          askAttempt: 3,
        ),
        'invalidate() booked behind a live refresh()': (
          liveVerb: (controller) => controller.refresh(),
          callVerb: (controller) => controller.invalidate(),
          failingAttempts: {3},
          askAttempt: 3,
        ),
      },
      outline: (tester, example) async {
        final server = FakeServer<int>([1, 2, 3])
          ..failing.addAll(example.failingAttempts.map((attempt) => (0, attempt)));
        final holdCompleter = server.hold(0, attempt: 2);
        final observer = RecordingListSmithObserver();
        final controller = ListSmithController<int>();
        await pumpList(tester, server, controller: controller, observer: observer);
        await drain(tester);
        unawaited(example.liveVerb?.call(controller));
        await drain(tester);

        final exceptionFuture = example.callVerb(controller);
        await release(tester, [holdCompleter]);

        final isAskFailing = example.failingAttempts.contains(example.askAttempt);
        check(server.attempts[0]).equals(example.askAttempt); // premise: its run fetched last
        check(await exceptionFuture).identicalTo(!isAskFailing ? null : observer.lastException);
      },
    );

    scenarioOutlineWidgets<AsyncValueSetter<ListSmithController<int>>?>(
      'a refresh() whose ask reset() cut off completes with null',
      examples: {
        'its own run': null,
        'booked behind a live invalidate()': (controller) => controller.invalidate(),
      },
      outline: (tester, liveVerb) async {
        // The held fetch fails, and so would a rerun after the cut.
        final server = FakeServer<int>([1, 2, 3])..failing.addAll({(0, 2), (0, 4)});
        final holdCompleter = server.hold(0, attempt: 2);
        final controller = ListSmithController<int>();
        await pumpList(tester, server, controller: controller);
        await drain(tester);
        unawaited(liveVerb?.call(controller));
        await drain(tester);
        final exceptionFuture = controller.refresh();
        await drain(tester);

        await controller.reset();
        await release(tester, [holdCompleter]);

        check(await exceptionFuture).isNull;
      },
    );
  });
}

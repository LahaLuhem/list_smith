import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

import '../support/support.dart';

void main() {
  feature('ListSmith.async 1st-page loads', () {
    Future<void> pumpList(
      WidgetTester tester,
      FakeServer<int> server, {
      ListSmithController<int>? controller,
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
        itemBuilder: (_, item, _) => SizedBox(height: 50, child: Text('item $item')),
      ),
    );

    scenarioOutlineWidgets<List<Future<void> Function(ListSmithController<int> controller)>>(
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

    scenarioOutlineWidgets<
      ({Future<void> Function(ListSmithController<int> controller) verb, bool isFailing})
    >(
      'a verb from code completes once its fresh page has landed or failed',
      examples: {
        'refresh(), landing': (verb: (controller) => controller.refresh(), isFailing: false),
        'refresh(), failing': (verb: (controller) => controller.refresh(), isFailing: true),
        'invalidate(), landing': (verb: (controller) => controller.invalidate(), isFailing: false),
        'invalidate(), failing': (verb: (controller) => controller.invalidate(), isFailing: true),
        'reset(), landing': (verb: (controller) => controller.reset(), isFailing: false),
        'reset(), failing': (verb: (controller) => controller.reset(), isFailing: true),
      },
      outline: (tester, example) async {
        final server = FakeServer<int>([1, 2, 3]);
        if (example.isFailing) server.failing.add((0, 2));
        final controller = ListSmithController<int>();
        await pumpList(tester, server, controller: controller);
        await drain(tester);
        final holdCompleter = server.hold(0, attempt: 2);

        var isDone = false;
        unawaited(example.verb(controller).then((_) => isDone = true));
        await drain(tester);
        check(server.attempts[0]).equals(2); // the fresh page is out, and held
        check(isDone).isFalse();
        await release(tester, [holdCompleter]);

        check(isDone).isTrue();
      },
    );

    scenarioWidgets('a pull hands over to the 1st-page loader instead of spinning beside it', (
      tester,
    ) async {
      final server = FakeServer<int>([1, 2, 3]);
      await pumpList(
        tester,
        server,
        refresh: PullToRefresh(
          indicatorBuilder: (_, _) => const SizedBox.expand(key: _indicatorKey),
        ),
      );
      await drain(tester);
      final holdCompleter = server.hold(0, attempt: 2);

      await pullToRefresh(tester, find.text('item 1'));
      // Premise: the list is on its loader, its fresh page still held.
      check(find.textContaining('item ').evaluate()).isEmpty();
      check(server.attempts[0]).equals(2);

      check(find.byKey(_indicatorKey).evaluate()).isEmpty();
      await release(tester, [holdCompleter]);
    });
  });
}

const _indicatorKey = ValueKey('indicator');

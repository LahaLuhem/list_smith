import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';
import 'package:list_smith/src/widgets/defaults/defaults.dart';

import '../../../support/support.dart';

void main() {
  feature('ListSmith.async after a failed reload', () {
    final errorFinder = find.byType(NeutralErrorIndicator);

    scenarioOutlineWidgets<({List<int> serverItems, bool isPull, String keptText})>(
      'its error shows above what the reload kept',
      examples: const {
        'rows, a pull with the default reload': (
          serverItems: [1, 2, 3],
          isPull: true,
          keptText: 'item 1',
        ),
        'rows, a depth reload from invalidate()': (
          serverItems: [1, 2, 3],
          isPull: false,
          keptText: 'item 1',
        ),
        'the empty screen, a pull': (serverItems: [], isPull: true, keptText: 'nothing here'),
      },
      outline: (tester, example) async {
        final server = FakeServer(example.serverItems)..failing.add((0, 2));
        final controller = await _pumpList(tester, server);

        await _reload(tester, controller, isPull: example.isPull);

        check(errorFinder.evaluate()).length.equals(1);
        check(tester.getBottomLeft(errorFinder).dy)
            .isLessOrEqual(tester.getTopLeft(find.text(example.keptText)).dy);
      },
    );

    scenarioWidgets('its error shows when a page read again at commit fails', (tester) async {
      final server = FakeServer(List.generate(8, (index) => index))..failing.add((0, 3));
      final controller = await _pumpList(tester, server, pageSize: 4);
      final secondPageHoldCompleter = server.hold(1, attempt: 2);
      unawaited(controller.invalidate());
      await tester.idle();
      await drain(tester, frames: 4);

      server.store.remove(1); // after page 0 is read, so the commit reads it again
      controller.remove(1);
      await tester.pump();
      await release(tester, [secondPageHoldCompleter]);

      check(server.attempts[0]).equals(3); // premise: that read went out
      check(errorFinder.evaluate()).length.equals(1);
    });

    scenarioOutlineWidgets<({bool isPull, FetchTrigger trigger})>(
      'Retry asks again with the trigger that failed',
      examples: const {
        'a pull': (isPull: true, trigger: .refresh),
        'invalidate()': (isPull: false, trigger: .invalidated),
      },
      outline: (tester, example) async {
        final server = FakeServer([1, 2, 3])..failing.add((0, 2));
        final controller = await _pumpList(tester, server);
        await _reload(tester, controller, isPull: example.isPull);
        final askedCount = server.requests.length;

        await tester.tap(find.byType(NeutralRetryButton));
        await drain(tester);

        final retryRequest = server.requests[askedCount];
        check((retryRequest.pageIndex, retryRequest.trigger)).equals((0, example.trigger));
      },
    );

    scenarioOutlineWidgets<({bool doesNextPageFail})>(
      'its error stays while a next page loads, then lands or fails',
      examples: const {
        'the next page lands': (doesNextPageFail: false),
        'the next page fails': (doesNextPageFail: true),
      },
      outline: (tester, example) async {
        final server = FakeServer(List.generate(6, (index) => index + 1))..failing.add((0, 2));
        if (example.doesNextPageFail) server.failing.add((1, 1));
        final nextPageHoldCompleter = server.hold(1, attempt: 1);
        await _pumpList(
          tester,
          server,
          pageSize: 3,
          surfaces: AsyncListSurfaces(
            reloadErrorBuilder: (_, _, _) => const Text('refresh failed'),
          ),
        );

        await pullToRefresh(tester, listScrollableFinder);
        // Premise: the pull failed while page 1 is still out.
        check(find.text('refresh failed').evaluate()).length.equals(1);
        await release(tester, [nextPageHoldCompleter]);

        check(find.text('refresh failed').evaluate()).length.equals(1);
      },
    );

    scenarioOutlineWidgets<({bool isReset})>(
      'its error goes once a reload lands or a reset clears the list',
      examples: const {'a reload that lands': (isReset: false), 'reset()': (isReset: true)},
      outline: (tester, example) async {
        final server = FakeServer([1, 2, 3])..failing.add((0, 2));
        final controller = await _pumpList(tester, server);
        await pullToRefresh(tester, listScrollableFinder);
        check(errorFinder.evaluate()).length.equals(1); // premise: the pull failed

        await (example.isReset ? controller.reset() : controller.refresh());
        await drain(tester);

        check(errorFinder.evaluate()).isEmpty;
        check(find.text('item 1').evaluate()).length.equals(1);
      },
    );

    scenarioWidgets('its error stays with the feed it failed on, through a search', (tester) async {
      final server = FakeServer([1, 2, 3])..failing.add((0, 2));
      final controller = await _pumpList(
        tester,
        server,
        search: AsyncSearch(
          fetchPage: SearchPageFetcher(
            (request) async => request.pageIndex == 0 ? const [99] : const <int>[],
          ),
          cachePolicy: const KeepCachePolicy(),
        ),
      );
      await pullToRefresh(tester, listScrollableFinder);
      check(errorFinder.evaluate()).length.equals(1); // premise: the feed's pull failed

      unawaited(controller.search('tea', searchDebounce: .zero));
      await settle(tester);
      check(find.text('item 99').evaluate()).length.equals(1);
      check(errorFinder.evaluate()).isEmpty;

      unawaited(controller.endSearch());
      await settle(tester);
      check(find.text('item 1').evaluate()).length.equals(1);
      check(errorFinder.evaluate()).length.equals(1);
    });
  });
}

/// [server]'s rows under the default pull, its empty screen reading "nothing here".
Future<ListSmithController<int>> _pumpList(
  WidgetTester tester,
  FakeServer<int> server, {
  int pageSize = 20,
  AsyncListSurfaces surfaces = const AsyncListSurfaces(),
  Search<int> search = const NoSearch(),
}) async {
  final controller = ListSmithController<int>();
  await pumpListSmith(
    tester,
    ListSmith.async(
      fetchPage: server.offsetLateFetcher,
      itemIdGetter: (item) => item,
      pageSize: pageSize,
      surfaces: surfaces,
      search: search,
      controller: controller,
      emptyBuilder: (_) => const Text('nothing here'),
      itemBuilder: (_, item, _) => Text('item $item'),
    ),
  );
  await drain(tester);

  return controller;
}

/// A pull, which runs the default reload, or [ListSmithController.invalidate], a depth reload.
Future<void> _reload(
  WidgetTester tester,
  ListSmithController<int> controller, {
  required bool isPull,
}) async {
  if (isPull) {
    await pullToRefresh(tester, listScrollableFinder);

    return;
  }

  await controller.invalidate();
  await drain(tester);
}

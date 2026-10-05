import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

import '../support/support.dart';

void main() {
  feature('ListSmith.async pull surfaces', () {
    Widget list(
      FakeServer<int> server, {
      ListScrollConfig scroll = const ListScrollConfig(),
      Refresh refresh = const PullToRefresh(),
      ListSmithController<int>? controller,
    }) => ListSmith.async(
      fetchPage: server.offsetLateFetcher,
      itemIdGetter: (item) => item,
      pageSize: 3,
      endPolicy: const FixedPageCountPolicy(pageCount: 1),
      scroll: scroll,
      refresh: refresh,
      controller: controller,
      itemBuilder: (_, item, _) => SizedBox.square(dimension: 50, child: Text('item $item')),
    );

    scenarioWidgets('a pull on the loader starts no refresh', (tester) async {
      final server = FakeServer<int>([1, 2, 3]);
      final firstLoadHoldCompleter = server.hold(0, attempt: 1);
      var isIndicatorShown = false;
      await pumpListSmith(
        tester,
        list(
          server,
          refresh: PullToRefresh(
            indicatorBuilder: (_, _) {
              isIndicatorShown = true;

              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await drain(tester);
      // Premise: the loader is up.
      check(find.textContaining('item ').evaluate()).isEmpty();

      await pullToRefresh(tester, find.byType(Scrollable));
      await release(tester, [firstLoadHoldCompleter]);

      check(isIndicatorShown).isFalse();
      check(server.attempts[0]).equals(1);
      // The same pull on the rows refreshes, so the one above did reach the list.
      await pullToRefresh(tester, find.byType(Scrollable));
      check(server.attempts[0]).equals(2);
    });

    scenarioOutlineWidgets<({Refresh refresh, Axis axis})>(
      'the loader stays still under a drag, where the rows follow it',
      examples: const {
        'pull-to-refresh on': (refresh: PullToRefresh(), axis: .vertical),
        'pull-to-refresh off': (refresh: NoRefresh(), axis: .vertical),
        'a horizontal list': (refresh: PullToRefresh(), axis: .horizontal),
      },
      outline: (tester, example) async {
        final server = FakeServer<int>([1, 2, 3]);
        final firstLoadHoldCompleter = server.hold(0, attempt: 1);
        // Bouncing physics, so whatever takes the drag visibly moves.
        await pumpListSmith(
          tester,
          ScrollConfiguration(
            behavior: const ScrollBehavior().copyWith(physics: const BouncingScrollPhysics()),
            child: list(
              server,
              scroll: ListScrollConfig(scrollDirection: example.axis),
              refresh: example.refresh,
            ),
          ),
        );
        await drain(tester);

        check(await _dragDistance(tester, example.axis)).equals(0);
        await release(tester, [firstLoadHoldCompleter]);
        check(await _dragDistance(tester, example.axis)).isGreaterThan(0);
      },
    );

    scenarioOutlineWidgets<_PullSetup>(
      'a surface that takes a pull takes it whatever the scroll setup',
      examples: {
        'a short list, with a ScrollController': (
          makeServer: () => FakeServer([1, 2, 3]),
          makeScroll: (controller) => ListScrollConfig(controller: controller),
          pullOffset: _pullDownOffset,
        ),
        'a short list, with explicit physics': (
          makeServer: () => FakeServer([1, 2, 3]),
          makeScroll: (_) => const ListScrollConfig(physics: BouncingScrollPhysics()),
          pullOffset: _pullDownOffset,
        ),
        'a short list, horizontal': (
          makeServer: () => FakeServer([1, 2, 3]),
          makeScroll: (_) => const ListScrollConfig(scrollDirection: .horizontal),
          pullOffset: const Offset(300, 0),
        ),
        'the 1st-page error, with a ScrollController': (
          makeServer: () => FakeServer([1, 2, 3])..failing.add((0, 1)),
          makeScroll: (controller) => ListScrollConfig(controller: controller),
          pullOffset: _pullDownOffset,
        ),
        'the empty list, with a ScrollController': (
          makeServer: () => FakeServer(<int>[]),
          makeScroll: (controller) => ListScrollConfig(controller: controller),
          pullOffset: _pullDownOffset,
        ),
      },
      outline: (tester, setup) async {
        final server = setup.makeServer();
        final scrollController = ScrollController();
        addTearDown(scrollController.dispose);
        await pumpListSmith(tester, list(server, scroll: setup.makeScroll(scrollController)));
        await drain(tester);

        await pullToRefresh(tester, _listScrollableFinder, offset: setup.pullOffset);

        check(server.attempts[0]).equals(2);
      },
    );

    scenarioOutlineWidgets<
      ({FakeServer<int> Function() makeServer, Set<PullableSurface> surfaces, bool isPulled})
    >(
      'a surface takes a pull only while the pull lists it',
      examples: {
        'the error, listed': (makeServer: _failingServer, surfaces: const {.error}, isPulled: true),
        'the error, left out': (
          makeServer: _failingServer,
          surfaces: const {.empty},
          isPulled: false,
        ),
        'the empty list, listed': (
          makeServer: _emptyServer,
          surfaces: const {.empty},
          isPulled: true,
        ),
        'the empty list, left out': (
          makeServer: _emptyServer,
          surfaces: const {.error},
          isPulled: false,
        ),
      },
      outline: (tester, example) async {
        final server = example.makeServer();
        await pumpListSmith(
          tester,
          list(server, refresh: PullToRefresh(pullableSurfaces: example.surfaces)),
        );
        await drain(tester);

        await pullToRefresh(tester, _listScrollableFinder);

        check(server.attempts[0]).equals(example.isPulled ? 2 : 1);
      },
    );

    scenarioWidgets("an app's NeverScrollableScrollPhysics keeps the list from taking a pull", (
      tester,
    ) async {
      final server = FakeServer<int>([1, 2, 3]);
      await pumpListSmith(
        tester,
        list(server, scroll: const ListScrollConfig(physics: NeverScrollableScrollPhysics())),
      );
      await drain(tester);

      await pullToRefresh(tester, find.byType(Scrollable));
      check(server.attempts[0]).equals(1);
      // Without it the same pull refreshes, so the one above did reach the list.
      await pumpListSmith(tester, list(server));
      await pullToRefresh(tester, find.byType(Scrollable));
      check(server.attempts[0]).equals(2);
    });

    scenarioWidgets('a pull the list resets under still lets go of its indicator', (tester) async {
      final server = FakeServer<int>([1, 2, 3]);
      final controller = ListSmithController<int>();
      await pumpListSmith(
        tester,
        list(
          server,
          controller: controller,
          refresh: PullToRefresh(
            indicatorBuilder: (_, _) => const SizedBox.expand(key: _indicatorKey),
          ),
        ),
      );
      await drain(tester);
      final holdCompleter = server.hold(0, attempt: 2);

      // Short of the arm threshold, so letting go cancels instead of refreshing.
      final gesture = await tester.startGesture(tester.getCenter(find.byType(Scrollable)));
      for (var step = 0; step < 3; step++) {
        await gesture.moveBy(const Offset(0, 20));
        await tester.pump(const Duration(milliseconds: 16));
      }
      // Premise: the pull is under way.
      check(find.byKey(_indicatorKey).evaluate()).length.equals(1);
      unawaited(controller.reset());
      await drain(tester);
      await gesture.up();
      // Timed frames, so the indicator's animation back to rest actually runs.
      for (var frame = 0; frame < 10; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      check(find.byKey(_indicatorKey).evaluate()).isEmpty();
      await release(tester, [holdCompleter]);
    });
  });
}

/// A list's data and scroll setup, and the drag that pulls it from its start edge.
typedef _PullSetup = ({
  FakeServer<int> Function() makeServer,
  ListScrollConfig Function(ScrollController controller) makeScroll,
  Offset pullOffset,
});

const _pullDownOffset = Offset(0, 300);

FakeServer<int> _failingServer() => FakeServer([1, 2, 3])..failing.add((0, 1));

FakeServer<int> _emptyServer() => FakeServer(<int>[]);

const _indicatorKey = ValueKey('indicator');

/// The list's own scroll view, ahead of the one the neutral error scrolls itself with.
final _listScrollableFinder = find.byType(Scrollable).first;

/// How far a held drag along [axis] moves the list. Starts in a corner, clear of a centred loader.
Future<double> _dragDistance(WidgetTester tester, Axis axis) async {
  final gesture = await tester.startGesture(
    tester.getTopLeft(find.byType(Scrollable)) + const Offset(20, 20),
  );
  for (var step = 0; step < 6; step++) {
    await gesture.moveBy(axis == .vertical ? const Offset(0, 30) : const Offset(30, 0));
    await tester.pump(const Duration(milliseconds: 16));
  }
  final distance = -tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels;
  await gesture.up();
  // Timed frames, so the list springs back before the next drag.
  for (var frame = 0; frame < 10; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }

  return distance;
}

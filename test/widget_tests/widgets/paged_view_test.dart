import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

import '../../support/support.dart';

void main() {
  feature('ListSmith.async drags on a surface', () {
    Widget list(
      FakeServer<int> server, {
      ListScrollConfig scrollConfig = const ListScrollConfig(),
      Refresh refresh = const PullToRefresh(),
    }) => ListSmith.async(
      fetchPage: server.offsetLateFetcher,
      itemIdGetter: (item) => item,
      pageSize: 3,
      endPolicy: const FixedPageCountPolicy(pageCount: 1),
      scroll: scrollConfig,
      refresh: refresh,
      itemBuilder: (_, item, _) => SizedBox.square(dimension: 50, child: Text('item $item')),
    );

    scenarioOutlineWidgets<({Refresh refresh, Axis scrollAxis})>(
      'the loader stays still under a drag, where the rows follow it',
      examples: const {
        'pull-to-refresh on': (refresh: PullToRefresh(), scrollAxis: .vertical),
        'pull-to-refresh off': (refresh: NoRefresh(), scrollAxis: .vertical),
        'a horizontal list': (refresh: PullToRefresh(), scrollAxis: .horizontal),
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
              scrollConfig: ListScrollConfig(scrollDirection: example.scrollAxis),
              refresh: example.refresh,
            ),
          ),
        );
        await drain(tester);

        check(await _dragDistance(tester, example.scrollAxis)).equals(0);
        await release(tester, [firstLoadHoldCompleter]);
        check(await _dragDistance(tester, example.scrollAxis)).isGreaterThan(0);
      },
    );

    scenarioOutlineWidgets<_DragCase>(
      'a drag carries the list past its ends on the rows, but on a surface only into a pull it takes',
      examples: {
        'the error, dragged away from the pull': (
          makeServer: _failingServer,
          refresh: const PullToRefresh(),
          scrollConfig: const ListScrollConfig(),
          startOffset: _cornerOffset,
          dragOffset: _awayFromPullOffset,
          isOverscrollExpected: false,
        ),
        'the empty list, dragged away from the pull': (
          makeServer: _emptyServer,
          refresh: const PullToRefresh(),
          scrollConfig: const ListScrollConfig(),
          startOffset: _cornerOffset,
          dragOffset: _awayFromPullOffset,
          isOverscrollExpected: false,
        ),
        'the error left out of pullableSurfaces, dragged towards the pull': (
          makeServer: _failingServer,
          refresh: const PullToRefresh(pullableSurfaces: {}),
          scrollConfig: const ListScrollConfig(),
          startOffset: _cornerOffset,
          dragOffset: _towardsPullOffset,
          isOverscrollExpected: false,
        ),
        'the error under NoRefresh, dragged towards the pull': (
          makeServer: _failingServer,
          refresh: const NoRefresh(),
          scrollConfig: const ListScrollConfig(),
          startOffset: _cornerOffset,
          dragOffset: _towardsPullOffset,
          isOverscrollExpected: false,
        ),
        "the loader, dragged from the list's padding": (
          makeServer: _loadingServer,
          refresh: const PullToRefresh(),
          scrollConfig: const ListScrollConfig(padding: .all(24)),
          startOffset: const Offset(8, 8),
          dragOffset: _towardsPullOffset,
          isOverscrollExpected: false,
        ),
        'short rows, dragged away from the pull': (
          makeServer: () => FakeServer([1, 2, 3]),
          refresh: const PullToRefresh(),
          scrollConfig: const ListScrollConfig(),
          startOffset: _cornerOffset,
          dragOffset: _awayFromPullOffset,
          isOverscrollExpected: true,
        ),
        'short rows under NoRefresh, dragged away from the pull': (
          makeServer: () => FakeServer([1, 2, 3]),
          refresh: const NoRefresh(),
          scrollConfig: const ListScrollConfig(),
          startOffset: _cornerOffset,
          dragOffset: _awayFromPullOffset,
          isOverscrollExpected: true,
        ),
      },
      outline: (tester, example) async {
        for (final platformPhysics in const [BouncingScrollPhysics(), ClampingScrollPhysics()]) {
          var isOverscrolled = false;
          await pumpListSmith(
            tester,
            ScrollConfiguration(
              behavior: const ScrollBehavior().copyWith(physics: platformPhysics),
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  // Bouncing physics leave the range, clamping ones report the overscroll instead.
                  if (notification.depth == 0 &&
                      (notification is OverscrollNotification || notification.metrics.outOfRange)) {
                    isOverscrolled = true;
                  }

                  return false;
                },
                child: list(
                  example.makeServer(),
                  refresh: example.refresh,
                  scrollConfig: example.scrollConfig,
                ),
              ),
            ),
          );
          await drain(tester);

          await _heldDrag(tester, startOffset: example.startOffset, dragOffset: example.dragOffset);

          check(because: '$platformPhysics', isOverscrolled).equals(example.isOverscrollExpected);
          await tester.pumpWidget(const SizedBox());
        }
      },
    );

    scenarioWidgets('in a NestedScrollView, a drag on an error still scrolls the header away', (
      tester,
    ) async {
      final nestedScrollViewKey = GlobalKey<NestedScrollViewState>();
      await pumpListSmith(
        tester,
        NestedScrollView(
          key: nestedScrollViewKey,
          headerSliverBuilder: (_, _) => const [SliverToBoxAdapter(child: SizedBox(height: 200))],
          body: list(_failingServer()),
        ),
      );
      await drain(tester);

      await tester.drag(find.text('Something went wrong'), const Offset(0, -100));
      await drain(tester);

      check(nestedScrollViewKey.currentState!.outerController.offset).isGreaterThan(0);
    });
  });
}

/// A list's data and setup, a held drag on it, and whether the drag should carry it past an end.
typedef _DragCase = ({
  FakeServer<int> Function() makeServer,
  Refresh refresh,
  ListScrollConfig scrollConfig,
  Offset startOffset,
  Offset dragOffset,
  bool isOverscrollExpected,
});

const _cornerOffset = Offset(20, 20);

const _towardsPullOffset = Offset(0, 30);

const _awayFromPullOffset = Offset(0, -30);

FakeServer<int> _failingServer() => FakeServer([1, 2, 3])..failing.add((0, 1));

FakeServer<int> _loadingServer() => FakeServer([1, 2, 3])..hold(0, attempt: 1);

FakeServer<int> _emptyServer() => FakeServer(<int>[]);

/// How far a held drag along [scrollAxis] moves the list. Starts in a corner, clear of a centred loader.
Future<double> _dragDistance(WidgetTester tester, Axis scrollAxis) async {
  final gesture = await tester.startGesture(
    tester.getTopLeft(find.byType(Scrollable)) + const Offset(20, 20),
  );
  for (var step = 0; step < 6; step++) {
    await gesture.moveBy(scrollAxis == .vertical ? const Offset(0, 30) : const Offset(30, 0));
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

/// Drags 6 steps of [dragOffset] from [startOffset] into the list, lets go, and lets a bounce settle.
Future<void> _heldDrag(
  WidgetTester tester, {
  required Offset startOffset,
  required Offset dragOffset,
}) async {
  final gesture = await tester.startGesture(tester.getTopLeft(listScrollableFinder) + startOffset);
  for (var step = 0; step < 6; step++) {
    await gesture.moveBy(dragOffset);
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  for (var frame = 0; frame < 10; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

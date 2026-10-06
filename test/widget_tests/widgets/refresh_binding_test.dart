// Test-local fixtures share the file with the scenarios that use them.
// ignore_for_file: prefer-match-file-name

import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

import '../../support/support.dart';

void main() {
  feature('ListSmith.async pull indicator', () {
    scenarioWidgets('an idle list under the neutral pull indicator requests no frames', (
      tester,
    ) async {
      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: pagedFetcher(const [
            [1, 2, 3],
          ]),
          itemIdGetter: (item) => item,
          itemBuilder: (_, item, _) => Text('item $item'),
        ),
      );
      await drain(tester);
      // Loaded to the end, so no page-loading spinner is left either.
      check(find.text('No more items').evaluate()).length.equals(1);

      await tester.pump(const Duration(seconds: 1));

      check(tester.binding.hasScheduledFrame).isFalse();
    });

    scenarioWidgets('a custom indicator is built only while a pull is in progress', (tester) async {
      final holdCompleter = Completer<List<int>>();
      var firstPageFetches = 0;
      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: PageFetcher((request) {
            if (request.pageIndex > 0) return Future.value(const <int>[]);
            firstPageFetches++;

            return firstPageFetches == 1 ? Future.value(const [1, 2, 3]) : holdCompleter.future;
          }),
          itemIdGetter: (item) => item,
          refresh: PullToRefresh(
            // A depth reload waits on its fetches, so the held one keeps the refresh running.
            reload: const ReloadToCurrentDepth(),
            indicatorBuilder: (_, _) => const _SpinningIndicator(),
          ),
          itemBuilder: (_, item, _) => Text('item $item'),
        ),
      );
      await drain(tester);
      check(find.text('item 1').evaluate()).length.equals(1);
      check(find.byType(_SpinningIndicator).evaluate()).isEmpty();

      await pullToRefresh(tester, find.text('item 1'));
      check(firstPageFetches).equals(2);
      check(find.byType(_SpinningIndicator).evaluate()).length.equals(1);

      holdCompleter.complete(const [1, 2, 3]);
      // Timed frames, so the indicator's animation back to rest actually runs.
      for (var frame = 0; frame < 5; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      check(find.byType(_SpinningIndicator).evaluate()).isEmpty();
      check(tester.binding.hasScheduledFrame).isFalse();
    });

    scenarioOutlineWidgets<_Orientation>(
      'the pull indicator sits at the edge the pull starts from, is told which way it travels, and '
      'the list moves away from it',
      examples: const {
        'a plain list, pulled down': (
          scrollConfig: ListScrollConfig(),
          textDirection: .ltr,
          pullDirection: .down,
        ),
        'a reversed list, pulled up': (
          scrollConfig: ListScrollConfig(reverse: true),
          textDirection: .ltr,
          pullDirection: .up,
        ),
        'a horizontal list, pulled right': (
          scrollConfig: ListScrollConfig(scrollDirection: .horizontal),
          textDirection: .ltr,
          pullDirection: .right,
        ),
        'a right-to-left horizontal list, pulled left': (
          scrollConfig: ListScrollConfig(scrollDirection: .horizontal),
          textDirection: .rtl,
          pullDirection: .left,
        ),
      },
      outline: (tester, orientation) async {
        final toldDirections = <AxisDirection>{};
        await pumpListSmith(
          tester,
          Directionality(
            textDirection: orientation.textDirection,
            child: ListSmith.async(
              fetchPage: pagedFetcher([_items]),
              itemIdGetter: (item) => item,
              scroll: orientation.scrollConfig,
              refresh: PullToRefresh(
                indicatorBuilder: (_, state) {
                  toldDirections.add(state.pullDirection);

                  return const SizedBox.expand(key: _indicatorKey);
                },
              ),
              itemBuilder: (_, item, _) => _Row(item),
            ),
          ),
        );
        await drain(tester);
        final restingList = tester.getRect(find.byType(Scrollable));
        final restingRow = tester.getRect(find.text('item 0'));

        final gesture = await _pullAndHold(tester, orientation.pullDirection);

        final unitOffset = _unit(orientation.pullDirection);
        double along(Offset offset) => offset.dx * unitOffset.dx + offset.dy * unitOffset.dy;

        final indicator = tester.getRect(find.byKey(_indicatorKey));
        check(_startEdge(indicator, orientation.pullDirection))
            .isCloseTo(_startEdge(restingList, orientation.pullDirection), 1);
        // Touching the start edge isn't enough: a slot along the wrong axis touches it too.
        check(along(indicator.center - restingList.center)).isLessThan(0);
        check(along(tester.getRect(find.text('item 0')).center - restingRow.center))
            .isGreaterThan(0);
        check(toldDirections).deepEquals({orientation.pullDirection});

        await gesture.up();
      },
    );

    scenarioWidgets("on bouncing physics the list isn't pushed on top of its own bounce", (
      tester,
    ) async {
      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: pagedFetcher([_items]),
          itemIdGetter: (item) => item,
          scroll: const ListScrollConfig(physics: BouncingScrollPhysics()),
          itemBuilder: (_, item, _) => _Row(item),
        ),
      );
      await drain(tester);
      final restingRow = tester.getRect(find.text('item 0'));

      final gesture = await _pullAndHold(tester, .down);

      final overshoot = -tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels;
      check(overshoot).isGreaterThan(0);
      check(tester.getRect(find.text('item 0')).top - restingRow.top).isCloseTo(overshoot, 1);

      await gesture.up();
    });

    scenarioOutlineWidgets<ListScrollConfig>(
      "while a refresh runs, the indicator doesn't cover the 1st row",
      examples: const {
        'clamping physics': ListScrollConfig(),
        'bouncing physics': ListScrollConfig(physics: BouncingScrollPhysics()),
      },
      outline: (tester, config) async {
        final holdCompleter = Completer<List<int>>();
        var firstPageFetches = 0;
        await pumpListSmith(
          tester,
          ListSmith.async(
            fetchPage: PageFetcher((request) {
              if (request.pageIndex > 0) return Future.value(const <int>[]);
              firstPageFetches++;

              return firstPageFetches == 1 ? Future.value(_items) : holdCompleter.future;
            }),
            itemIdGetter: (item) => item,
            scroll: config,
            refresh: PullToRefresh(
              // Waits on the held fetch, so the refresh keeps running.
              reload: const ReloadToCurrentDepth(),
              indicatorBuilder: (_, _) => const SizedBox.expand(key: _indicatorKey),
            ),
            itemBuilder: (_, item, _) => _Row(item),
          ),
        );
        await drain(tester);

        await pullToRefresh(tester, find.text('item 0'));
        check(firstPageFetches).equals(2);

        final indicator = tester.getRect(find.byKey(_indicatorKey));
        check(indicator.overlaps(tester.getRect(find.text('item 0')))).isFalse();

        holdCompleter.complete(_items);
      },
    );

    scenarioWidgets(
      'the indicator gets the configured room, and a full pull moves the list that far',
      (tester) async {
        const double extent = 100;
        await pumpListSmith(
          tester,
          ListSmith.async(
            fetchPage: pagedFetcher([_items]),
            itemIdGetter: (item) => item,
            refresh: PullToRefresh(
              indicatorExtent: extent,
              indicatorBuilder: (_, _) => const SizedBox.expand(key: _indicatorKey),
            ),
            itemBuilder: (_, item, _) => _Row(item),
          ),
        );
        await drain(tester);
        final restingRow = tester.getRect(find.text('item 0'));

        // Well past the arm threshold, so the pull is a full one.
        final gesture = await _pullAndHold(tester, .down);

        check(tester.getRect(find.byKey(_indicatorKey)).height).isCloseTo(extent, 1);
        check(tester.getRect(find.text('item 0')).top - restingRow.top).isCloseTo(extent, 1);

        await gesture.up();
      },
    );

    scenarioWidgets('a pull the list resets under still lets go of its indicator', (tester) async {
      final server = FakeServer<int>([1, 2, 3]);
      final controller = ListSmithController<int>();
      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: server.offsetLateFetcher,
          itemIdGetter: (item) => item,
          pageSize: 3,
          endPolicy: const FixedPageCountPolicy(pageCount: 1),
          controller: controller,
          refresh: PullToRefresh(
            indicatorBuilder: (_, _) => const SizedBox.expand(key: _indicatorKey),
          ),
          itemBuilder: (_, item, _) => SizedBox.square(dimension: 50, child: Text('item $item')),
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

typedef _Orientation = ({
  ListScrollConfig scrollConfig,
  TextDirection textDirection,
  AxisDirection pullDirection,
});

const _indicatorKey = ValueKey('indicator');

/// Enough rows to overfill the viewport along either axis, so every orientation can scroll.
final _items = List<int>.generate(30, (index) => index);

/// Drags from the list's centre towards [pull] and keeps the finger down, so a test can look mid-pull.
Future<TestGesture> _pullAndHold(WidgetTester tester, AxisDirection pull) async {
  final gesture = await tester.startGesture(tester.getCenter(find.byType(Scrollable)));
  // Stepped, a frame each, so the drag clears touch slop and the indicator follows it.
  for (var step = 0; step < 12; step++) {
    await gesture.moveBy(_unit(pull) * 30);
    await tester.pump(const Duration(milliseconds: 16));
  }

  return gesture;
}

Offset _unit(AxisDirection direction) => switch (direction) {
  .down => const Offset(0, 1),
  .up => const Offset(0, -1),
  .right => const Offset(1, 0),
  .left => const Offset(-1, 0),
};

/// The side of [rect] that a pull travelling towards [pull] starts from.
double _startEdge(Rect rect, AxisDirection pull) => switch (pull) {
  .down => rect.top,
  .up => rect.bottom,
  .right => rect.left,
  .left => rect.right,
};

class const _Row(final int item) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SizedBox.square(dimension: 100, child: Text('item $item'));
}

/// Spins for as long as it's mounted, so one left behind at rest keeps asking for frames.
class const _SpinningIndicator() extends StatefulWidget {
  @override
  State<_SpinningIndicator> createState() => _SpinningIndicatorState();
}

class _SpinningIndicatorState()
    extends State<_SpinningIndicator>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))
    ..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RotationTransition(turns: _controller, child: const Text('spinner'));
}

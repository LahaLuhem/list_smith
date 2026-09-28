// Test-local widgets share the file with the scenarios that drive them.
// ignore_for_file: prefer-match-file-name

import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

import '../support/support.dart';

void main() {
  feature('ListSmith.async surface paths', () {
    scenarioWidgets('a failing later page shows the new-page error surface', (tester) async {
      await _pumpAsync(
        tester,
        fetchPage: PageFetcher((request) async {
          if (request.pageIndex == 0) return const [1, 2, 3];

          throw Exception('later page');
        }),
        surfaces: AsyncListSurfaces(newPageErrorBuilder: (_, _, _) => const Text('later failed')),
      );
      await drain(tester);

      // Page 0's items stay while the failed page 1 shows its own error footer.
      check(find.text('item 1').evaluate()).length.equals(1);
      check(find.text('later failed').evaluate()).length.equals(1);
    });

    scenarioWidgets('a separator builder renders the separated list', (tester) async {
      await _pumpAsync(
        tester,
        fetchPage: PageFetcher(
          (request) async => request.pageIndex == 0 ? const [1, 2, 3] : const <int>[],
        ),
        separatorBuilder: (_, _) => const Text('sep'),
      );
      await drain(tester);

      check(find.text('item 1').evaluate()).length.equals(1);
      // Separators fall between the items (and before the end-of-list footer).
      check(find.text('sep').evaluate()).length.isGreaterThan(1);
    });

    scenarioWidgets('an idle list under the neutral pull indicator requests no frames', (
      tester,
    ) async {
      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: pagedFetcher(const [
            [1, 2, 3],
          ]),
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
      final hold = Completer<List<int>>();
      var firstPageFetches = 0;
      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: PageFetcher((request) {
            if (request.pageIndex > 0) return Future.value(const <int>[]);
            firstPageFetches++;

            return firstPageFetches == 1 ? Future.value(const [1, 2, 3]) : hold.future;
          }),
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

      hold.complete(const [1, 2, 3]);
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
        'a plain list, pulled down': (scroll: ListScrollConfig(), text: .ltr, pull: .down),
        'a reversed list, pulled up': (
          scroll: ListScrollConfig(reverse: true),
          text: .ltr,
          pull: .up,
        ),
        'a horizontal list, pulled right': (
          scroll: ListScrollConfig(scrollDirection: .horizontal),
          text: .ltr,
          pull: .right,
        ),
        'a right-to-left horizontal list, pulled left': (
          scroll: ListScrollConfig(scrollDirection: .horizontal),
          text: .rtl,
          pull: .left,
        ),
      },
      outline: (tester, orientation) async {
        final toldDirections = <AxisDirection>{};
        await pumpListSmith(
          tester,
          Directionality(
            textDirection: orientation.text,
            child: ListSmith.async(
              fetchPage: pagedFetcher([_items]),
              scroll: orientation.scroll,
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

        final gesture = await _pullAndHold(tester, orientation.pull);

        final unit = _unit(orientation.pull);
        double along(Offset offset) => offset.dx * unit.dx + offset.dy * unit.dy;

        final indicator = tester.getRect(find.byKey(_indicatorKey));
        check(_startEdge(indicator, orientation.pull))
            .isCloseTo(_startEdge(restingList, orientation.pull), 1);
        // Touching the start edge isn't enough: a slot along the wrong axis touches it too.
        check(along(indicator.center - restingList.center)).isLessThan(0);
        check(along(tester.getRect(find.text('item 0')).center - restingRow.center))
            .isGreaterThan(0);
        check(toldDirections).deepEquals({orientation.pull});

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
      outline: (tester, scroll) async {
        final hold = Completer<List<int>>();
        var firstPageFetches = 0;
        await pumpListSmith(
          tester,
          ListSmith.async(
            fetchPage: PageFetcher((request) {
              if (request.pageIndex > 0) return Future.value(const <int>[]);
              firstPageFetches++;

              return firstPageFetches == 1 ? Future.value(_items) : hold.future;
            }),
            scroll: scroll,
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

        hold.complete(_items);
      },
    );

    scenarioWidgets('the neutral spinner repaints when the ambient colour changes', (tester) async {
      final hold = Completer<List<int>>();
      Widget build(Color colour) => DefaultTextStyle(
        style: TextStyle(color: colour),
        child: ListSmith.async(
          fetchPage: PageFetcher(
            (request) => request.pageIndex == 0 ? hold.future : Future.value(const <int>[]),
          ),
          refresh: const NoRefresh(),
          itemBuilder: (_, item, _) => Text('item $item'),
        ),
      );

      // Held on the 1st page, so the neutral spinner is what is on screen.
      await pumpListSmith(tester, build(const Color(0xFFFF0000)));
      await drain(tester);
      check(find.byType(CustomPaint).evaluate()).isNotEmpty();

      // Re-pump under a different ambient colour: the arc painter has to notice and repaint.
      await pumpListSmith(tester, build(const Color(0xFF0000FF)));
      await drain(tester);
      check(find.byType(CustomPaint).evaluate()).isNotEmpty();

      hold.complete(const [1]);
      await tester.idle();
      await drain(tester);
      check(find.text('item 1').evaluate()).length.equals(1);
    });
  });

  feature('ListSmith.sync rebuild and layout', () {
    scenarioWidgets('replacing the items list after build re-materialises and re-filters', (
      tester,
    ) async {
      await _pumpSync(tester, items: const ['apple', 'banana'], searchBy: containsIgnoreCase);
      await tester.pump();
      check(find.text('apple').evaluate()).length.equals(1);

      await _pumpSync(tester, items: const ['cherry', 'date'], searchBy: containsIgnoreCase);
      await tester.pump();

      check(find.text('cherry').evaluate()).length.equals(1);
      check(find.text('apple').evaluate()).length.equals(0);
    });

    scenarioWidgets('changing the query after build commits a new filter', (tester) async {
      // Same const list on both pumps, so only the query changes (isolates the query path).
      const items = ['apple', 'banana'];
      await _pumpSync(tester, items: items, searchBy: containsIgnoreCase);
      await tester.pump();
      check(find.text('banana').evaluate()).length.equals(1);

      await _pumpSync(tester, items: items, searchBy: containsIgnoreCase, query: 'app');
      // Fire the zero-duration debounce timer so the new query commits.
      await tester.pump(const Duration(milliseconds: 1));

      check(find.text('apple').evaluate()).length.equals(1);
      check(find.text('banana').evaluate()).length.equals(0);
    });

    scenarioWidgets('applies a custom cache extent', (tester) async {
      await _pumpSync(
        tester,
        items: const ['apple'],
        searchBy: containsIgnoreCase,
        scroll: const ListScrollConfig(cacheExtent: 250),
      );
      await tester.pump();

      check(find.text('apple').evaluate()).length.equals(1);
    });

    scenarioWidgets('a separator builder renders the separated list', (tester) async {
      await _pumpSync(
        tester,
        items: const ['apple', 'banana'],
        searchBy: containsIgnoreCase,
        separatorBuilder: (_, _) => const Text('sep'),
      );
      await tester.pump();

      check(find.text('apple').evaluate()).length.equals(1);
      // 2 items yield one separator.
      check(find.text('sep').evaluate()).length.equals(1);
    });
  });
}

Future<void> _pumpAsync(
  WidgetTester tester, {
  required PageFetcher<int> fetchPage,
  AsyncListSurfaces surfaces = const AsyncListSurfaces(),
  IndexedWidgetBuilder? separatorBuilder,
}) => pumpListSmith(
  tester,
  ListSmith.async(
    fetchPage: fetchPage,
    surfaces: surfaces,
    separatorBuilder: separatorBuilder,
    refresh: const NoRefresh(),
    itemBuilder: (_, item, _) => Text('item $item'),
  ),
);

Future<void> _pumpSync(
  WidgetTester tester, {
  required List<String> items,
  required SyncSearchPredicate<String> searchBy,
  String query = '',
  IndexedWidgetBuilder? separatorBuilder,
  ListScrollConfig scroll = const ListScrollConfig(),
}) => pumpListSmith(
  tester,
  ListSmith.sync(
    items: items,
    searchBy: searchBy,
    query: query,
    separatorBuilder: separatorBuilder,
    scroll: scroll,
    itemBuilder: (_, item, _) => Text(item),
  ),
);

typedef _Orientation = ({ListScrollConfig scroll, TextDirection text, AxisDirection pull});

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

class _Row extends StatelessWidget {
  final int item;

  const new(this.item);

  @override
  Widget build(BuildContext context) => SizedBox.square(dimension: 100, child: Text('item $item'));
}

/// Spins for as long as it's mounted, so one left behind at rest keeps asking for frames.
class _SpinningIndicator extends StatefulWidget {
  const new();

  @override
  State<_SpinningIndicator> createState() => _SpinningIndicatorState();
}

class _SpinningIndicatorState extends State<_SpinningIndicator>
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

import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

import '../support/support.dart';

void main() {
  feature('ListSmith.async edit transitions', () {
    scenarioWidgets('an upserted item grows in once, then stays put', (tester) async {
      final controller = await _pumpRows(tester);

      controller.upsert(0);
      await tester.pump();
      final heights = [_heightOf(0)];
      for (var frame = 0; frame < 4; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
        heights.add(_heightOf(0));
      }
      controller.upsert(0); // already shown, so it changes in place
      await tester.pump();
      heights.add(_heightOf(0));

      check(heights.first).equals(0);
      check(heights[1])
        ..isGreaterThan(0)
        ..isLessThan(heights[2]);
      check(heights.skip(3)).every((height) => height.equals(50));
    });

    scenarioWidgets('rows a page brings in show at full size at once', (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await _pumpRows(
        tester,
        fetchPage: pagedFetcher([_range(0, 19), _range(20, 39)]),
        pageCount: 2,
        scroll: ListScrollConfig(controller: scroll),
        isDrained: false,
      );

      await tester.pump();
      await tester.pump();
      check(_heightOf(0)).equals(50);
      await drain(tester, frames: 12);
      scroll.jumpTo(1500);
      await tester.pump();
      check(_heightOf(35)).equals(50);
    });

    scenarioWidgets('a new row keeps its state once its entry ends', (tester) async {
      final controller = await _pumpRows(tester);

      controller.upsert(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      check(_heightOf(0)).isLessThan(50);
      await _tapShowingPart(tester, 0);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      check(_heightOf(0)).equals(50);
      check(shownToggleRows().first).equals('on 0');
    });

    scenarioWidgets('a removed row shrinks away while the row below stays whole', (tester) async {
      final controller = await _pumpRows(tester);

      controller.remove(2);
      await _startExit(tester);
      await tester.pump(const Duration(milliseconds: 150));
      final leavingHeight = _heightOf(2);

      check(leavingHeight)
        ..isGreaterThan(0)
        ..isLessThan(50);
      check(_heightOf(3)).equals(50);
      check(_topOf(tester, 3)).equals(_topOf(tester, 2) + leavingHeight);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      check(shownToggleRows()).deepEquals(['off 1', 'off 3']);
    });

    scenarioOutlineWidgets<({ListScrollConfig scroll, DismissDirection direction, Offset swipe})>(
      'a row that shrank itself goes at once, with no list exit',
      examples: {
        'down a list': (
          scroll: const ListScrollConfig(),
          direction: .endToStart,
          swipe: const Offset(-700, 0),
        ),
        'down a reversed list': (
          scroll: const ListScrollConfig(reverse: true),
          direction: .endToStart,
          swipe: const Offset(-700, 0),
        ),
        'across a sideways list': (
          scroll: const ListScrollConfig(scrollDirection: .horizontal),
          direction: .up,
          swipe: const Offset(0, -500),
        ),
      },
      outline: (tester, example) async {
        final dismissed = <int>[];
        await _pumpRows(
          tester,
          scroll: example.scroll,
          dismissDirection: example.direction,
          dismissed: dismissed,
          duration: const Duration(seconds: 1), // long, so a list exit would still be running
        );

        await tester.drag(find.text('off 2'), example.swipe);
        for (var frame = 0; frame < 20 && dismissed.isEmpty; frame++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        check(dismissed).deepEquals([2]);
        await tester.pump();
        await tester.pump();

        check(tester.takeException()).isNull();
        check(find.text('off 2').evaluate()).isEmpty();
      },
    );

    scenarioWidgets('an upsert mid-exit brings the row back whole, state kept', (tester) async {
      final controller = await _pumpRows(tester);
      await tester.tap(find.text('off 2'));
      await tester.pump();

      controller.remove(2);
      await _startExit(tester);
      await tester.pump(const Duration(milliseconds: 150));
      check(_heightOf(2)).isLessThan(50);
      controller.upsert(2);
      await tester.pump(); // a restarted ticker's 1st frame has no time in it
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      check(_heightOf(2)).equals(50);
      check(shownToggleRows()).deepEquals(['off 1', 'on 2', 'off 3']);
      await tester.pump(const Duration(seconds: 1));
      check(shownToggleRows()).deepEquals(['off 1', 'on 2', 'off 3']);
    });

    scenarioWidgets('with animations turned off, edits show at once', (tester) async {
      final controller = await _pumpRows(tester, isMotionReduced: true);

      controller.upsert(0);
      await tester.pump();
      check(_heightOf(0)).equals(50);
      controller.remove(2);
      await tester.pump();
      await tester.pump();

      check(shownToggleRows()).deepEquals(['off 0', 'off 1', 'off 3']);
    });

    scenarioWidgets('turning transitions off mid-exit takes the leaving row at once', (
      tester,
    ) async {
      final controller = await _pumpRows(tester);

      controller.remove(2);
      await _startExit(tester);
      await tester.pump(const Duration(milliseconds: 100));
      check(_heightOf(2)).isLessThan(50);
      await _pumpRows(tester, controller: controller, isTransitionOn: false);

      check(shownToggleRows()).deepEquals(['off 1', 'off 3']);
    });

    scenarioWidgets('a reload committing mid-exit keeps the leaving row hidden', (tester) async {
      final server = FakeServer(const [1, 2, 3]); // still has 2: the server is behind
      final controller = await _pumpRows(
        tester,
        fetchPage: server.offsetEarly,
        refresh: const PullToRefresh(reload: ReloadToCurrentDepth()),
      );
      final hold = server.hold(0, attempt: 2);

      controller.remove(2);
      await _startExit(tester);
      await tester.pump(const Duration(milliseconds: 100));
      unawaited(controller.refresh());
      await tester.pump();
      await release(tester, [hold]);
      check(server.attempts[0]).equals(2); // the re-read committed while row 2 was leaving
      check(_heightOf(2)).isLessThan(50);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      check(shownToggleRows()).deepEquals(['off 1', 'off 3']);
    });

    scenarioWidgets('an entering item moves to where the server puts it, state kept', (
      tester,
    ) async {
      final server = FakeServer(const [1, 2, 3]);
      final controller = await _pumpRows(
        tester,
        fetchPage: server.offsetLate,
        refresh: const PullToRefresh(reload: ReloadToCurrentDepth()),
      );

      server.store.insert(2, 9); // the server files it between 2 and 3
      controller.upsert(9);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      check(_heightOf(9)).isLessThan(50);
      await _tapShowingPart(tester, 9);
      await controller.refresh();
      await drain(tester, frames: 12);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      check(shownToggleRows()).deepEquals(['off 1', 'off 2', 'on 9', 'off 3']);
    });

    scenarioWidgets('exits that empty the list end on the empty surface', (tester) async {
      final controller = await _pumpRows(
        tester,
        items: const [1, 2],
        emptyBuilder: (_) => const Text('nothing here'),
      );

      controller
        ..remove(1)
        ..remove(2);
      await _startExit(tester);
      await tester.pump(const Duration(milliseconds: 150));
      check(find.text('nothing here').evaluate()).isEmpty();
      await tester.pump(const Duration(milliseconds: 300));
      await drain(tester);

      check(find.text('nothing here').evaluate()).length.equals(1);
    });

    scenarioWidgets('a removal while searching stays out of the kept feed', (tester) async {
      final controller = ListSmithController<int>();
      await _pumpKept(tester, controller, query: '');
      await _pumpKept(tester, controller, query: 'q');
      await settle(tester);

      controller.remove(4);
      await _startExit(tester);
      await tester.pump(const Duration(milliseconds: 150));
      check(_heightOf(4)).isLessThan(50);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await _pumpKept(tester, controller, query: '');
      await settle(tester);

      check(shownToggleRows()).deepEquals(['off 1', 'off 2', 'off 3', 'off 5', 'off 6']);
    });

    scenarioWidgets('a new item while searching joins the feed without animating', (tester) async {
      final controller = ListSmithController<int>();
      await _pumpKept(tester, controller, query: '');
      await _pumpKept(tester, controller, query: 'q');
      await settle(tester);

      controller.upsert(100);
      await tester.pump();
      check(shownToggleRows()).deepEquals(['off 2', 'off 4', 'off 6']);
      await _pumpKept(tester, controller, query: '');
      await settle(tester);

      check(shownToggleRows().first).equals('off 100');
      check(_heightOf(100)).equals(50);
    });

    scenarioWidgets('a query change mid-exit lands the removal', (tester) async {
      final controller = ListSmithController<int>();
      await _pumpKept(tester, controller, query: '');

      controller.remove(3);
      await _startExit(tester);
      await tester.pump(const Duration(milliseconds: 100));
      check(_heightOf(3)).isLessThan(50);
      await _pumpKept(tester, controller, query: 'q');
      await settle(tester);
      await _pumpKept(tester, controller, query: ''); // back well inside the exit's time
      await settle(tester);

      check(shownToggleRows()).deepEquals(['off 1', 'off 2', 'off 4', 'off 5', 'off 6']);
    });

    scenarioWidgets('reset() mid-exit lands the removal before starting over', (tester) async {
      final server = FakeServer(const [1, 2, 3]); // still has 2, so the fresh read shows it
      final controller = await _pumpRows(tester, fetchPage: server.offsetLate);

      controller.remove(2);
      await _startExit(tester);
      await tester.pump(const Duration(milliseconds: 100));
      check(_heightOf(2)).isLessThan(50);
      await controller.reset();
      await drain(tester, frames: 12);

      check(shownToggleRows()).deepEquals(['off 1', 'off 2', 'off 3']);
      check(_heightOf(2)).equals(50);
    });

    scenarioWidgets('an entry in progress stops at reset()', (tester) async {
      final server = FakeServer(const [1, 2, 3]);
      final controller = await _pumpRows(tester, fetchPage: server.offsetLate);

      server.store.insert(0, 0);
      controller.upsert(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      check(_heightOf(0)).isLessThan(50);
      await controller.reset();
      await drain(tester, frames: 12);

      check(shownToggleRows().first).equals('off 0');
      check(_heightOf(0)).equals(50);
    });

    scenarioWidgets('a new group-first item grows in under a header that stays whole', (
      tester,
    ) async {
      final controller = await _pumpRows(tester, items: const [10, 11, 20], grouping: _byTens);

      controller.upsert(12); // joins the start of group 1
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      final growing = find.ancestor(of: _rowOf(12), matching: find.byType(SizeTransition));

      check(growing.evaluate()).length.equals(1);
      check(find.descendant(of: growing, matching: find.text('group 1')).evaluate()).isEmpty();
      check(find.text('group 1').evaluate()).length.equals(1);
      check(tester.getTopLeft(find.text('group 1')).dy).isLessThan(_topOf(tester, 12));
    });

    scenarioWidgets('a leaving group-first row keeps the header until it is gone', (tester) async {
      final controller = await _pumpRows(tester, items: const [10, 11, 20], grouping: _byTens);
      await tester.tap(find.text('off 11'));
      await tester.pump();

      controller.remove(10);
      await _startExit(tester);
      await tester.pump(const Duration(milliseconds: 150));
      check(_heightOf(10)).isLessThan(50);
      check(tester.getTopLeft(find.text('group 1')).dy).isLessThan(_topOf(tester, 10));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      check(shownToggleRows()).deepEquals(['on 11', 'off 20']);
      check(find.text('group 1').evaluate()).length.equals(1);
      check(tester.getTopLeft(find.text('group 1')).dy).isLessThan(_topOf(tester, 11));
    });
  });
}

final _byTens = Grouping.by<int, int>(
  groupBy: (item) => item ~/ 10,
  headerBuilder: (_, key) => Text('group $key'),
);

/// Pumps a list of [ToggleRow]s that grow in and out from their top edge, so a half-grown row still
/// shows its top half.
Future<ListSmithController<int>> _pumpRows(
  WidgetTester tester, {
  List<int> items = const [1, 2, 3],
  PageFetcher<int>? fetchPage,
  int pageCount = 1,
  ListSmithController<int>? controller,
  Refresh refresh = const NoRefresh(),
  Grouping<int>? grouping,
  Search<int> search = const NoSearch(),
  String query = '',
  ListScrollConfig scroll = const ListScrollConfig(),
  Duration duration = const Duration(milliseconds: 300),
  DismissDirection? dismissDirection,
  List<int>? dismissed,
  WidgetBuilder? emptyBuilder,
  bool isMotionReduced = false,
  bool isTransitionOn = true,
  bool isDrained = true,
}) async {
  final handle = controller ?? ListSmithController<int>();
  final axis = scroll.scrollDirection;
  final list = ListSmith.async(
    fetchPage: fetchPage ?? pagedFetcher([items]),
    itemIdGetter: (item) => item,
    endPolicy: FixedPageCountPolicy(pageCount: pageCount),
    refresh: refresh,
    grouping: grouping,
    search: search,
    query: query,
    searchDebounce: const Duration(milliseconds: 20),
    scroll: scroll,
    emptyBuilder: emptyBuilder,
    controller: handle,
    editTransition: !isTransitionOn
        ? const NoEditTransition()
        : EditTransition(
            duration: duration,
            transitionBuilder: (child, animation) => SizeTransition(
              sizeFactor: animation,
              axis: axis,
              alignment: .topStart,
              child: child,
            ),
          ),
    itemBuilder: (_, item, _) => dismissDirection == null
        ? ToggleRow(item)
        : Dismissible(
            key: ValueKey(item),
            direction: dismissDirection,
            onDismissed: (_) {
              dismissed?.add(item);
              handle.remove(item);
            },
            child: ToggleRow(item),
          ),
  );
  await pumpListSmith(
    tester,
    isMotionReduced
        ? MediaQuery(data: const MediaQueryData(disableAnimations: true), child: list)
        : list,
  );
  if (isDrained) await drain(tester);

  return handle;
}

/// A feed of 1 to 6 kept by [KeepCachePolicy] under a search that returns the even rows.
Future<void> _pumpKept(
  WidgetTester tester,
  ListSmithController<int> controller, {
  required String query,
}) => _pumpRows(
  tester,
  items: _range(1, 6),
  controller: controller,
  query: query,
  search: AsyncSearch(
    fetchPage: pagedSearchFetcher(const [
      [2, 4, 6],
    ]),
    cachePolicy: const KeepCachePolicy(),
  ),
);

/// Pumps the frame that checks whether a removed row shrank itself, then the exit's 1st frame.
Future<void> _startExit(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

/// Taps [item]'s row near its top edge, the part a growing row already shows.
Future<void> _tapShowingPart(WidgetTester tester, int item) async {
  await tester.tapAt(tester.getTopLeft(_rowOf(item)) + const Offset(20, 5));
  await tester.pump();
}

/// A row that hasn't grown yet has no height, which the list counts as offstage, hence
/// `skipOffstage: false`.
Finder _rowOf(int item) => find.byWidgetPredicate(
  (widget) => widget is ToggleRow && widget.item == item,
  skipOffstage: false,
);

/// How much of [item]'s row shows: its transition's size while one runs, the row's own otherwise.
double _heightOf(int item) {
  final row = _rowOf(item);
  final transitionElement = find
      .ancestor(of: row, matching: find.byType(SizeTransition, skipOffstage: false))
      .evaluate()
      .firstOrNull;

  return (transitionElement ?? row.evaluate().single).size!.height;
}

double _topOf(WidgetTester tester, int item) => tester.getTopLeft(_rowOf(item)).dy;

List<int> _range(int from, int to) => List.generate(to - from + 1, (index) => from + index);

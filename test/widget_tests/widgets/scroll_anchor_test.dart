// Test-local fixtures share the file with the scenarios that use them.
// ignore_for_file: prefer-match-file-name

import 'dart:async';
import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

import '../../support/support.dart';

typedef _Row = ({int id, double rank});

typedef _Mount = Future<ListSmithController<_Row>> Function(
  WidgetTester tester,
  ScrollController scrollController,
);

void main() {
  feature('ListSmith.async keeps what the user is reading in place', () {
    scenarioOutlineWidgets<({_Mount mount, ValueSetter<ListSmithController<_Row>> edit})>(
      'a row on screen holds still on every frame while rows above it change',
      examples: {
        'a new row at the start': (
          mount: _mount(),
          edit: (controller) => controller.upsert(_row(100)),
        ),
        'a row above leaving': (mount: _mount(), edit: (controller) => controller.remove(_row(5))),
        'a row sorting from on screen to the start': (
          mount: _mount(order: _rankOrder),
          edit: (controller) => controller.upsert(_row(30, rank: -1)),
        ),
        'a new row opening a group at the start': (
          mount: _mount(grouping: _tensGrouping),
          edit: (controller) => controller.upsert(_row(100)),
        ),
        'a new row at the start of a reversed list': (
          mount: _mount(reverse: true),
          edit: (controller) => controller.upsert(_row(100)),
        ),
        'a new row at the start, with separators': (
          mount: _mount(separatorBuilder: (_, _) => const SizedBox(height: 10)),
          edit: (controller) => controller.upsert(_row(100)),
        ),
        'a new row growing in at the start': (
          mount: _mount(editTransition: _growInTransition),
          edit: (controller) => controller.upsert(_row(100)),
        ),
        'a new row growing in just above': (
          mount: _mount(order: _rankOrder, editTransition: _growInTransition),
          edit: (controller) => controller.upsert(_row(100, rank: 17.5)),
        ),
        'a draft at the start, then its save': (
          mount: _mount(),
          edit: (controller) => unawaited(
            controller.upsertAsync(_row(100), commit: Future.delayed(_saveDelay, () => _row(100))),
          ),
        ),
        'a removal above, then its failed save': (
          mount: _mount(),
          edit: (controller) => unawaited(
            controller.removeAsync(
              _row(5),
              commit: Future.delayed(_saveDelay, () => throw Exception('save failed')),
            ),
          ),
        ),
      },
      outline: (tester, example) async {
        final scrollController = _scrollController();
        final controller = await example.mount(tester, scrollController);
        final topBefore = _topOf(tester, 20);
        final pixelsBefore = scrollController.position.pixels;

        example.edit(controller);
        final frameTops = <double>[];
        final framePixels = <double>[];
        for (var frame = 0; frame < 8; frame++) {
          await tester.pump(const Duration(milliseconds: 50));
          frameTops.add(_topOf(tester, 20));
          framePixels.add(scrollController.position.pixels);
        }

        check(frameTops).every((it) => it.equals(topBefore));
        // The edit did land: the view moved with it.
        check(framePixels).any((it) => it.not((it) => it.equals(pixelsBefore)));
      },
    );

    scenarioWidgets('a fling carries on smoothly when a row lands above', (tester) async {
      final controller = await _mount()(tester, _scrollController());
      Future<double> frameStep() async {
        final topBefore = _topOf(tester, 30);
        await tester.pump(const Duration(milliseconds: 16));

        return _topOf(tester, 30) - topBefore;
      }

      await tester.fling(find.text('item 22'), const Offset(0, -300), 1000);
      await tester.pump();
      final flingStep = await frameStep();
      controller.upsert(_row(100));
      final upsertStep = await frameStep();

      // A fling slows a little each frame, a slide would add a whole row.
      check((upsertStep - flingStep).abs()).isLessThan(_rowExtent / 2);
    });

    scenarioWidgets('a row the user switched on keeps its state and its place', (tester) async {
      final controller = await _mount(itemBuilder: (_, row, _) => ToggleRow(row.id))(
        tester,
        _scrollController(),
      );
      await tester.tap(find.text('off 20'));
      await tester.pump();
      final topBefore = tester.getTopLeft(find.text('on 20')).dy;

      controller.upsert(_row(100));
      await tester.pump();

      check(tester.getTopLeft(find.text('on 20')).dy).equals(topBefore);
    });

    scenarioWidgets('scrolling back to the start after a taller row landed above has no jumps', (
      tester,
    ) async {
      final scrollController = _scrollController();
      final controller = await _mount(
        itemBuilder: (_, row, _) =>
            SizedBox(height: row.id == 100 ? 120 : _rowExtent, child: Text('item ${row.id}')),
      )(tester, scrollController);
      controller.upsert(_row(100));
      await tester.pump();

      final jumps = <String>[];
      for (var step = 0; step < 40 && scrollController.position.pixels > 0; step++) {
        final topsBefore = _shownTops(tester);
        final pixelsBefore = scrollController.position.pixels;
        final targetPixels = math.max<double>(0, pixelsBefore - 40);
        scrollController.jumpTo(targetPixels);
        await tester.pump();
        final topsAfter = _shownTops(tester);
        jumps.addAll(
          topsBefore.keys
              .where(topsAfter.containsKey)
              .where(
                (label) => topsAfter[label]! - topsBefore[label]! != pixelsBefore - targetPixels,
              )
              .map((label) => 'step $step, $label'),
        );
      }

      check(jumps).isEmpty();
    });

    scenarioWidgets('at the very start, a new row shows on top', (tester) async {
      final controller = await _mount(scrollOffset: 0)(tester, _scrollController());
      final firstTop = _topOf(tester, 0);

      controller.upsert(_row(100));
      await tester.pump();

      check(_topOf(tester, 100)).equals(firstTop);
    });

    scenarioOutlineWidgets<int>(
      'the row after a removed one takes its place',
      examples: const {'the row on top': 20, 'a row below it': 25},
      outline: (tester, removedId) async {
        final controller = await _mount()(tester, _scrollController());
        final removedTop = _topOf(tester, removedId);

        controller.remove(_row(removedId));
        await tester.pump();

        check(_topOf(tester, removedId + 1)).equals(removedTop);
      },
    );

    scenarioOutlineWidgets<({List<_Row> newRows, bool reverse})>(
      'a row on screen holds still on every frame as a pull ends away from the start',
      examples: {
        'nothing new on the server': (newRows: const [], reverse: false),
        'a new row on the server, at the start': (newRows: [_row(100)], reverse: false),
        'a reversed list': (newRows: const [], reverse: true),
      },
      outline: (tester, example) async {
        final server = FakeServer(_rows);
        final scrollController = _scrollController();
        await _mount(
          scrollOffset: 0,
          server: server,
          refresh: _depthPullRefresh,
          reverse: example.reverse,
        )(tester, scrollController);
        final holdCompleter = server.hold(0, attempt: 2);
        await pullToRefresh(
          tester,
          find.text('item 0'),
          offset: Offset(0, example.reverse ? -300 : 300),
        );
        scrollController.jumpTo(1000);
        await tester.pump();
        final topWhileOut = _topOf(tester, 20);
        check(find.byKey(_indicatorKey).evaluate()).isNotEmpty(); // premise: still out

        server.store.insertAll(0, example.newRows);
        final frameTops = await _releaseAndRecord(tester, holdCompleter, () => _topOf(tester, 20));

        check(frameTops).every((it) => it.equals(topWhileOut));
        check(find.byKey(_indicatorKey).evaluate()).isEmpty(); // the pull did end
      },
    );

    scenarioWidgets('at the very start, a pull still pushes the rows and lets them back', (
      tester,
    ) async {
      final server = FakeServer(_rows);
      await _mount(scrollOffset: 0, server: server, refresh: _depthPullRefresh)(
        tester,
        _scrollController(),
      );
      final topAtRest = _topOf(tester, 0);
      final holdCompleter = server.hold(0, attempt: 2);

      await pullToRefresh(tester, find.text('item 0'));
      final topWhileOut = _topOf(tester, 0);
      final frameTops = await _releaseAndRecord(tester, holdCompleter, () => _topOf(tester, 0));

      check(topWhileOut).isGreaterThan(topAtRest);
      check(frameTops.last).equals(topAtRest);
    });

    scenarioWidgets("scrolled less than the pull's room away, the rows stop at the start", (
      tester,
    ) async {
      final server = FakeServer(_rows);
      final scrollController = _scrollController();
      await _mount(scrollOffset: 0, server: server, refresh: _depthPullRefresh)(
        tester,
        scrollController,
      );
      final topAtRest = _topOf(tester, 0);
      final holdCompleter = server.hold(0, attempt: 2);

      await pullToRefresh(tester, find.text('item 0'));
      scrollController.jumpTo(30);
      await tester.pump();
      final framePixels = await _releaseAndRecord(
        tester,
        holdCompleter,
        () => scrollController.position.pixels,
      );

      check(framePixels).every((it) => it.isGreaterOrEqual(0)); // never past the start
      check(_topOf(tester, 0)).equals(topAtRest);
    });

    scenarioWidgets(
      'without shouldKeepPosition, a row on screen holds still as a row lands above',
      (tester) async {
        final scrollController = _scrollController();
        final controller = ListSmithController<_Row>();
        // Built here rather than by _mount, which always passes the flag.
        await pumpListSmith(
          tester,
          ListSmith<_Row>.async(
            fetchPage: FakeServer(_rows).offsetLateFetcher,
            itemIdGetter: (row) => row.id,
            pageSize: _rows.length,
            controller: controller,
            scroll: ListScrollConfig(controller: scrollController),
            itemBuilder: (_, row, _) => SizedBox(height: _rowExtent, child: Text('item ${row.id}')),
          ),
        );
        await drain(tester);
        scrollController.jumpTo(1000);
        await tester.pump();
        final topBefore = _topOf(tester, 20);
        final pixelsBefore = scrollController.position.pixels;

        controller.upsert(_row(100));
        await tester.pump();

        check(_topOf(tester, 20)).equals(topBefore);
        // The row did land above: the position moved with it.
        check(scrollController.position.pixels).isGreaterThan(pixelsBefore);
      },
    );

    scenarioWidgets('with shouldKeepPosition off, a row landing above leaves the position alone', (
      tester,
    ) async {
      final scrollController = _scrollController();
      final controller = await _mount(shouldKeepPosition: false)(tester, scrollController);
      final topBefore = _topOf(tester, 20);
      final pixelsBefore = scrollController.position.pixels;

      controller.upsert(_row(100));
      await tester.pump();

      check(scrollController.position.pixels).equals(pixelsBefore);
      check(_topOf(tester, 20)).isGreaterThan(topBefore); // the row did land above
    });

    scenarioWidgets(
      'with shouldKeepPosition off, a pull ending away from the start leaves the position alone',
      (tester) async {
        final server = FakeServer(_rows);
        final scrollController = _scrollController();
        await _mount(
          scrollOffset: 0,
          server: server,
          refresh: _depthPullRefresh,
          shouldKeepPosition: false,
        )(tester, scrollController);
        final holdCompleter = server.hold(0, attempt: 2);
        await pullToRefresh(tester, find.text('item 0'));
        scrollController.jumpTo(1000);
        await tester.pump();
        final topWhileOut = _topOf(tester, 20);
        final pixelsWhileOut = scrollController.position.pixels;

        final framePixels = await _releaseAndRecord(
          tester,
          holdCompleter,
          () => scrollController.position.pixels,
        );

        check(framePixels).every((it) => it.equals(pixelsWhileOut));
        check(_topOf(tester, 20)).isLessThan(topWhileOut); // the room did let go
      },
    );
  });
}

/// Pumps the rows from one page, then scrolls to [scrollOffset], `item 20` on top by default.
_Mount _mount({
  double scrollOffset = 1000,
  FakeServer<_Row>? server,
  Refresh refresh = const PullToRefresh(),
  ItemBuilder<_Row>? itemBuilder,
  ItemOrder<_Row> order = const UnknownOrder(),
  EditTransition editTransition = const NoEditTransition(),
  Grouping<_Row>? grouping,
  IndexedWidgetBuilder? separatorBuilder,
  bool reverse = false,
  bool shouldKeepPosition = true,
}) => (tester, scrollController) async {
  final controller = ListSmithController<_Row>();
  await pumpListSmith(
    tester,
    ListSmith<_Row>.async(
      fetchPage: (server ?? FakeServer(_rows)).offsetLateFetcher,
      itemIdGetter: (row) => row.id,
      pageSize: _rows.length,
      refresh: refresh,
      order: order,
      editTransition: editTransition,
      shouldKeepPosition: shouldKeepPosition,
      grouping: grouping,
      separatorBuilder: separatorBuilder,
      controller: controller,
      scroll: ListScrollConfig(controller: scrollController, reverse: reverse),
      itemBuilder:
          itemBuilder ?? (_, row, _) => SizedBox(height: _rowExtent, child: Text('item ${row.id}')),
    ),
  );
  await drain(tester);
  scrollController.jumpTo(scrollOffset);
  await tester.pump();

  return controller;
};

_Row _row(int id, {double? rank}) => (id: id, rank: rank ?? id.toDouble());

final _rows = List.generate(50, _row);

const _rowExtent = 50.0;

const _indicatorKey = ValueKey('indicator');

/// A depth reload waits on its fetches, so a held one keeps the pull out.
final _depthPullRefresh = PullToRefresh(
  reload: const ReloadToCurrentDepth(),
  indicatorBuilder: (_, _) => const SizedBox.expand(key: _indicatorKey),
);

/// Lets the held reload through, then reads [read] after each of a second's 50 ms frames.
Future<List<T>> _releaseAndRecord<T>(
  WidgetTester tester,
  Completer<void> holdCompleter,
  ValueGetter<T> read,
) async {
  holdCompleter.complete();
  final readings = <T>[];
  for (var frame = 0; frame < 20; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
    readings.add(read());
  }

  return readings;
}

final _rankOrder = SortedBy<_Row>((a, b) => a.rank.compareTo(b.rank));

final _tensGrouping = Grouping.by<_Row, int>(
  groupBy: (row) => row.id ~/ 10,
  headerBuilder: (_, key) => SizedBox(height: 30, child: Text('group $key')),
);

final _growInTransition = EditTransition(
  duration: const Duration(milliseconds: 250),
  transitionBuilder: (child, animation) => SizeTransition(sizeFactor: animation, child: child),
);

const _saveDelay = Duration(milliseconds: 100);

/// The top edge of the row showing [id], on screen or not.
double _topOf(WidgetTester tester, int id) =>
    tester.getTopLeft(find.text('item $id', skipOffstage: false)).dy;

/// Each row on screen by its label, with its top edge.
Map<String, double> _shownTops(WidgetTester tester) => Map.fromEntries(
  find
      .textContaining('item ')
      .evaluate()
      .map(
        (element) => MapEntry(
          (element.widget as Text).data!,
          tester.getTopLeft(find.byWidget(element.widget)).dy,
        ),
      ),
);

ScrollController _scrollController() {
  final scrollController = ScrollController();
  addTearDown(scrollController.dispose);

  return scrollController;
}

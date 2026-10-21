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
    scenarioOutlineWidgets<({_Mount mount, void Function(ListSmithController<_Row>) edit})>(
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
  });
}

/// Pumps 50 rows from one page, then scrolls to [scrollOffset], `item 20` on top by default.
_Mount _mount({
  double scrollOffset = 1000,
  ItemBuilder<_Row>? itemBuilder,
  ItemOrder<_Row> order = const UnknownOrder(),
  EditTransition editTransition = const NoEditTransition(),
  Grouping<_Row>? grouping,
  IndexedWidgetBuilder? separatorBuilder,
  bool reverse = false,
}) => (tester, scrollController) async {
  final controller = ListSmithController<_Row>();
  await pumpListSmith(
    tester,
    ListSmith<_Row>.async(
      fetchPage: pagedFetcher([List.generate(50, _row)]),
      itemIdGetter: (row) => row.id,
      order: order,
      editTransition: editTransition,
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

const _rowExtent = 50.0;

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

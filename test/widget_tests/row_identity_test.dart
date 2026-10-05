import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

import '../support/support.dart';

void main() {
  feature('ListSmith.async rows follow their item', () {
    scenarioWidgets('a row keeps its state when an item lands above it', (tester) async {
      final controller = await _pumpRows(tester, const [1, 2, 3]);
      await tester.tap(find.text('off 2'));
      await tester.pump();

      controller.upsert(0);
      await tester.pump();

      check(shownToggleRows()).deepEquals(['off 0', 'off 1', 'on 2', 'off 3']);
    });

    scenarioWidgets('a row keeps its state when a row above is swiped away', (tester) async {
      await _pumpRows(tester, const [1, 2, 3, 4]);
      await tester.tap(find.text('off 4'));
      await tester.pump();

      await tester.drag(find.text('off 1'), const Offset(-700, 0));
      await _finishSwipes(tester);

      check(shownToggleRows()).deepEquals(['off 2', 'off 3', 'on 4']);
    });

    scenarioWidgets('a 2nd swipe while the 1st still animates dismisses both', (tester) async {
      final dismissed = <int>[];
      await _pumpRows(tester, const [1, 2, 3, 4, 5, 6], dismissed: dismissed);

      await tester.drag(find.text('off 1'), const Offset(-700, 0));
      await tester.pump(const Duration(milliseconds: 250)); // row 1 is shrinking by now
      await tester.drag(find.text('off 2'), const Offset(-700, 0));
      await _finishSwipes(tester);

      check(dismissed).deepEquals([1, 2]);
      check(shownToggleRows()).deepEquals(['off 3', 'off 4', 'off 5', 'off 6']);
    });

    scenarioWidgets('a swipe finishes when an item lands above it mid-swipe', (tester) async {
      final dismissed = <int>[];
      final controller = await _pumpRows(tester, const [1, 2, 3], dismissed: dismissed);

      await tester.drag(find.text('off 2'), const Offset(-700, 0));
      await tester.pump(const Duration(milliseconds: 100));
      controller.upsert(0);
      await _finishSwipes(tester);

      check(dismissed).deepEquals([2]);
      check(shownToggleRows()).deepEquals(['off 0', 'off 1', 'off 3']);
    });

    scenarioOutlineWidgets<({List<int> items, void Function(ListSmithController<int>) applyEdit})>(
      'a row keeps its state as its group header comes and goes',
      examples: {
        'gaining the header': (
          items: const [10, 11, 12, 20],
          applyEdit: (controller) => controller.remove(10),
        ),
        'losing the header': (
          items: const [11, 12, 20],
          applyEdit: (controller) => controller.upsert(10),
        ),
      },
      outline: (tester, example) async {
        final controller = await _pumpRows(
          tester,
          example.items,
          grouping: Grouping.by(
            groupBy: (item) => item ~/ 10,
            headerBuilder: (_, key) => Text('group $key'),
          ),
        );
        await tester.tap(find.text('off 11'));
        await tester.pump();

        example.applyEdit(controller);
        await tester.pump();

        check(shownToggleRows()).contains('on 11');
        check(find.text('group 1').evaluate()).length.equals(1);
      },
    );
  });
}

/// Pumps [items] as one page of stateful, swipeable rows. A swiped row is removed and lands in
/// [dismissed].
Future<ListSmithController<int>> _pumpRows(
  WidgetTester tester,
  List<int> items, {
  List<int>? dismissed,
  Grouping<int>? grouping,
}) async {
  final controller = ListSmithController<int>();
  await pumpListSmith(
    tester,
    ListSmith.async(
      fetchPage: pagedFetcher([items]),
      itemIdGetter: (item) => item,
      endPolicy: const FixedPageCountPolicy(pageCount: 1),
      refresh: const NoRefresh(),
      grouping: grouping,
      controller: controller,
      itemBuilder: (_, item, _) => Dismissible(
        key: ValueKey(item),
        onDismissed: (_) {
          dismissed?.add(item);
          controller.remove(item);
        },
        child: ToggleRow(item),
      ),
    ),
  );
  await drain(tester);

  return controller;
}

/// Pumps past a Dismissible's slide and shrink.
Future<void> _finishSwipes(WidgetTester tester) async {
  for (var frame = 0; frame < 12; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

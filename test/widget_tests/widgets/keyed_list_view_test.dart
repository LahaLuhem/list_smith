import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

import '../../support/support.dart';

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

    scenarioOutlineWidgets<({List<int> items, ValueSetter<ListSmithController<int>> applyEdit})>(
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

  feature('ListSmith.async group headers', () {
    scenarioWidgets('the row being read holds still when a new row takes its header', (
      tester,
    ) async {
      final (controller, scrollController) = await _pumpGrouped(tester);
      scrollController.jumpTo(1060); // group 2's header on top, item 20 under it
      await tester.pump();
      final shownTop = _topOf(tester, 20);

      controller.upsert(200); // joins the start of group 2
      await tester.pump();

      check(_topOf(tester, 20)).equals(shownTop);
    });

    scenarioWidgets('the row being read holds still when it gains its header', (tester) async {
      final (controller, scrollController) = await _pumpGrouped(tester);
      scrollController.jumpTo(1140); // item 21 on top, item 20 opening its group above
      await tester.pump();
      final shownTop = _topOf(tester, 21);

      controller.remove(20);
      await tester.pump();

      check(_topOf(tester, 21)).equals(shownTop);
    });

    scenarioWidgets('a header keeps its state when a group lands above it', (tester) async {
      final controller = ListSmithController<int>();
      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: pagedFetcher([
            const [10, 11, 20],
          ]),
          itemIdGetter: (item) => item,
          endPolicy: const FixedPageCountPolicy(pageCount: 1),
          refresh: const NoRefresh(),
          grouping: Grouping.by<int, int>(
            groupBy: (item) => item ~/ 10,
            headerBuilder: (_, key) => ToggleRow(key),
          ),
          controller: controller,
          itemBuilder: (_, item, _) => Text('item $item'),
        ),
      );
      await drain(tester);
      await tester.tap(find.text('off 2'));
      await tester.pump();

      controller.upsert(0); // group 0 isn't loaded, so it goes on top
      await tester.pump();

      check(shownToggleRows()).deepEquals(['off 0', 'off 1', 'on 2']);
    });

    scenarioWidgets('on a reversed list, a header sits above its group', (tester) async {
      await _pumpGrouped(tester, reverse: true);

      // Group 0 runs from item 0 at the bottom up to item 9.
      check(tester.getBottomLeft(find.text('group 0')).dy).equals(_topOf(tester, 9));
      check(tester.getTopLeft(find.text('group 0')).dy)
          .equals(tester.getBottomLeft(find.text('item 10')).dy);
    });
  });

  feature('ListSmith.async surfaces and separators', () {
    scenarioOutlineWidgets<_SurfaceHost>(
      "a surface gets exactly the list's height, however tall it asks to be",
      examples: _surfaceHosts,
      outline: (tester, host) async {
        await host(tester, (_) => const SizedBox(key: _surfaceKey, height: 2000));
        await drain(tester);

        check(tester.getSize(find.byKey(_surfaceKey)).height)
            .equals(tester.getSize(find.byType(Scrollable)).height);
      },
    );

    scenarioOutlineWidgets<_SurfaceHost>(
      'a surface built with a LayoutBuilder renders',
      examples: _surfaceHosts,
      outline: (tester, host) async {
        await host(
          tester,
          (_) => LayoutBuilder(
            builder: (_, constraints) => Text('surface at ${constraints.maxHeight}'),
          ),
        );
        await drain(tester);

        check(find.textContaining('surface at').evaluate()).length.equals(1);
      },
    );

    scenarioOutlineWidgets<_SurfaceHost>(
      'a surface built with Expanded renders',
      examples: _surfaceHosts,
      outline: (tester, host) async {
        await host(
          tester,
          (_) => const Column(
            children: [
              Expanded(child: Text('fills')),
              Text('below'),
            ],
          ),
        );
        await drain(tester);

        check(find.text('fills').evaluate()).length.equals(1);
        check(find.text('below').evaluate()).length.equals(1);
      },
    );

    scenarioOutlineWidgets<({ListScrollConfig scrollConfig, EdgeInsets safeAreaInsets})>(
      'a short surface leaves nothing to scroll, padding included',
      examples: const {
        'padding all round': (
          scrollConfig: ListScrollConfig(padding: .all(24)),
          safeAreaInsets: .zero,
        ),
        "the screen's safe area, with no padding set": (
          scrollConfig: ListScrollConfig(),
          safeAreaInsets: .only(top: 47, bottom: 34),
        ),
        'a reversed list': (
          scrollConfig: ListScrollConfig(reverse: true, padding: .only(top: 30, bottom: 10)),
          safeAreaInsets: .zero,
        ),
        'a horizontal list': (
          scrollConfig: ListScrollConfig(
            scrollDirection: .horizontal,
            padding: .only(left: 10, right: 30),
          ),
          safeAreaInsets: .zero,
        ),
      },
      outline: (tester, example) async {
        await pumpListSmith(
          tester,
          MediaQuery(
            data: MediaQueryData(padding: example.safeAreaInsets),
            child: ListSmith.async(
              fetchPage: PageFetcher((_) async => throw Exception('down')),
              itemIdGetter: (item) => item,
              scroll: example.scrollConfig,
              itemBuilder: (_, item, _) => Text('item $item'),
            ),
          ),
        );
        await drain(tester);

        check(tester.state<ScrollableState>(listScrollableFinder).position.maxScrollExtent)
            .equals(0);
      },
    );

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

/// Pumps items `0..49` as 50 px rows, grouped by tens (200 joins group 2) under 30 px headers.
Future<(ListSmithController<int>, ScrollController)> _pumpGrouped(
  WidgetTester tester, {
  bool reverse = false,
}) async {
  final controller = ListSmithController<int>();
  final scrollController = ScrollController();
  await pumpListSmith(
    tester,
    ListSmith.async(
      fetchPage: pagedFetcher([List.generate(50, (item) => item)]),
      itemIdGetter: (item) => item,
      endPolicy: const FixedPageCountPolicy(pageCount: 1),
      refresh: const NoRefresh(),
      grouping: Grouping.by<int, int>(
        groupBy: (item) => item < 100 ? item ~/ 10 : item ~/ 100,
        headerBuilder: (_, key) => SizedBox(height: 30, child: Text('group $key')),
      ),
      controller: controller,
      scroll: ListScrollConfig(controller: scrollController, reverse: reverse),
      itemBuilder: (_, item, _) => SizedBox(height: 50, child: Text('item $item')),
    ),
  );
  await drain(tester);

  return (controller, scrollController);
}

double _topOf(WidgetTester tester, int item) =>
    tester.getTopLeft(find.text('item $item', skipOffstage: false)).dy;

/// Pumps past a Dismissible's slide and shrink.
Future<void> _finishSwipes(WidgetTester tester) async {
  for (var frame = 0; frame < 12; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pumpAsync(
  WidgetTester tester, {
  required PageFetcher<int> fetchPage,
  AsyncListSurfaces surfaces = const AsyncListSurfaces(),
  WidgetBuilder? emptyBuilder,
  IndexedWidgetBuilder? separatorBuilder,
}) => pumpListSmith(
  tester,
  ListSmith.async(
    fetchPage: fetchPage,
    itemIdGetter: (item) => item,
    surfaces: surfaces,
    emptyBuilder: emptyBuilder,
    separatorBuilder: separatorBuilder,
    refresh: const NoRefresh(),
    itemBuilder: (_, item, _) => Text('item $item'),
  ),
);

/// Pumps a list showing only [surface].
typedef _SurfaceHost = Future<void> Function(WidgetTester tester, WidgetBuilder surface);

final _surfaceHosts = <String, _SurfaceHost>{
  'the loader': (tester, surface) {
    final holdCompleter = Completer<List<int>>();
    addTearDown(() => holdCompleter.complete(const []));

    return _pumpAsync(
      tester,
      fetchPage: PageFetcher((_) => holdCompleter.future),
      surfaces: AsyncListSurfaces(firstPageLoadingBuilder: surface),
    );
  },
  'the 1st-page error': (tester, surface) => _pumpAsync(
    tester,
    fetchPage: PageFetcher((_) async => throw Exception('down')),
    surfaces: AsyncListSurfaces(firstPageErrorBuilder: (context, _, _) => surface(context)),
  ),
  'the empty list': (tester, surface) =>
      _pumpAsync(tester, fetchPage: PageFetcher((_) async => const []), emptyBuilder: surface),
};

const _surfaceKey = ValueKey('surface');

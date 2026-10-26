// Test-local fixtures share the file with the scenarios that use them.
// ignore_for_file: prefer-match-file-name

import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

import '../../support/support.dart';

void main() {
  feature('ListSmith.sync surfaces', () {
    scenarioWidgets('shows all items when there is no query', (tester) async {
      await _pumpSync(tester, items: const ['apple', 'banana'], searchBy: containsIgnoreCase);
      await tester.pump();

      check(find.text('apple').evaluate()).length.equals(1);
      check(find.text('banana').evaluate()).length.equals(1);
    });

    scenarioWidgets('shows the empty surface when there are no items', (tester) async {
      await _pumpSync(tester, items: const <String>[], searchBy: containsIgnoreCase);
      await tester.pump();

      check(find.text('No items').evaluate()).length.equals(1);
    });

    scenarioWidgets('filters to the matches when a query is set', (tester) async {
      await _pumpSync(
        tester,
        items: const ['apple', 'banana'],
        searchBy: containsIgnoreCase,
        query: 'app',
      );
      await tester.pump();

      check(find.text('apple').evaluate()).length.equals(1);
      check(find.text('banana').evaluate()).length.equals(0);
    });

    scenarioOutlineWidgets<({String firstQuery, String? nextQuery})>(
      'a query shorter than minSearchLength shows every item',
      examples: const {
        'as the 1st query': (firstQuery: 'ap', nextQuery: null),
        'typed after': (firstQuery: '', nextQuery: 'ap'),
      },
      outline: (tester, example) async {
        await _pumpSync(
          tester,
          items: const ['apple', 'banana'],
          searchBy: containsIgnoreCase,
          query: example.firstQuery,
          minSearchLength: 3,
        );
        final nextQuery = example.nextQuery;
        if (nextQuery != null) {
          await _pumpSync(
            tester,
            items: const ['apple', 'banana'],
            searchBy: containsIgnoreCase,
            query: nextQuery,
            minSearchLength: 3,
          );
        }
        await settle(tester);

        check(find.text('banana').evaluate()).length.equals(1);
      },
    );

    scenarioWidgets('shows the no-results surface when a query matches nothing', (tester) async {
      await _pumpSync(
        tester,
        items: const ['apple', 'banana'],
        searchBy: containsIgnoreCase,
        query: 'xyz',
      );
      await tester.pump();

      check(find.text('No results').evaluate()).length.equals(1);
    });

    scenarioWidgets('an empty surface built with a LayoutBuilder renders', (tester) async {
      await _pumpSync(
        tester,
        items: const [],
        searchBy: containsIgnoreCase,
        emptyBuilder: (_) =>
            LayoutBuilder(builder: (_, constraints) => Text('surface at ${constraints.maxHeight}')),
      );
      await drain(tester);

      check(find.textContaining('surface at').evaluate()).length.equals(1);
    });

    scenarioWidgets('an empty surface built with Expanded renders', (tester) async {
      await _pumpSync(
        tester,
        items: const [],
        searchBy: containsIgnoreCase,
        emptyBuilder: (_) => const Column(
          children: [
            Expanded(child: Text('fills')),
            Text('below'),
          ],
        ),
      );
      await drain(tester);

      check(find.text('fills').evaluate()).length.equals(1);
      check(find.text('below').evaluate()).length.equals(1);
    });
  });

  feature('ListSmith.sync rows follow their item', () {
    scenarioOutlineWidgets<_RowsChange>(
      'the row being read holds still when the app changes the rows above it',
      examples: {
        'an item lands on top': (
          scrollOffset: 1000,
          change: (items, _) => [100, ...items],
          reverse: false,
          separatorBuilder: null,
          grouping: null,
        ),
        'an item above goes': (
          scrollOffset: 1000,
          change: (items, _) => [...items]..remove(5),
          reverse: false,
          separatorBuilder: null,
          grouping: null,
        ),
        'a built row above grows': (
          scrollOffset: 1000,
          change: (items, heights) {
            heights[18] = 150;

            return [...items];
          },
          reverse: false,
          separatorBuilder: null,
          grouping: null,
        ),
        'an item lands on top of a reversed list': (
          scrollOffset: 1000,
          change: (items, _) => [100, ...items],
          reverse: true,
          separatorBuilder: null,
          grouping: null,
        ),
        'an item lands on top, with separators': (
          scrollOffset: 1200,
          change: (items, _) => [100, ...items],
          reverse: false,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          grouping: null,
        ),
        'an item lands on top in a new group': (
          scrollOffset: 1060,
          change: (items, _) => [100, ...items],
          reverse: false,
          separatorBuilder: null,
          grouping: Grouping.by<int, int>(
            groupBy: (item) => item ~/ 10,
            headerBuilder: (_, key) => SizedBox(height: 30, child: Text('group $key')),
          ),
        ),
      },
      outline: (tester, example) async {
        final heights = <int, double>{};
        final itemsNotifier = ValueNotifier(List.generate(50, (item) => item));
        final scrollController = ScrollController();
        await _pumpRows(
          tester,
          itemsNotifier,
          scrollController: scrollController,
          reverse: example.reverse,
          separatorBuilder: example.separatorBuilder,
          grouping: example.grouping,
          itemBuilder: (_, item, _) =>
              SizedBox(height: heights[item] ?? 50, child: Text('item $item')),
        );
        scrollController.jumpTo(example.scrollOffset);
        await tester.pump();
        final shownTop = _topOf(tester, 20);

        itemsNotifier.value = example.change(itemsNotifier.value, heights);
        await tester.pump();

        check(_topOf(tester, 20)).equals(shownTop);
      },
    );

    scenarioWidgets('at the very start, a new item shows on top', (tester) async {
      final itemsNotifier = ValueNotifier(List.generate(50, (item) => item));
      await _pumpRows(tester, itemsNotifier);

      itemsNotifier.value = [100, ...itemsNotifier.value];
      await tester.pump();

      check(_topOf(tester, 100)).equals(0);
    });

    scenarioOutlineWidgets<List<int> Function(List<int> items)>(
      'a row keeps its state when the app changes the rows above it',
      examples: {
        'an item lands on top': (items) => [100, ...items],
        'an item above goes': (items) => [...items]..remove(1),
      },
      outline: (tester, change) async {
        final itemsNotifier = ValueNotifier(List.generate(10, (item) => item));
        await _pumpRows(tester, itemsNotifier, itemBuilder: (_, item, _) => ToggleRow(item));
        await tester.tap(find.text('off 3'));
        await tester.pump();

        itemsNotifier.value = change(itemsNotifier.value);
        await tester.pump();

        check(shownToggleRows().where((row) => row.startsWith('on'))).deepEquals(['on 3']);
      },
    );

    scenarioWidgets('the scroll controller stays attached while nothing matches', (tester) async {
      final scrollController = ScrollController();
      await _pumpSync(
        tester,
        items: const ['apple', 'banana'],
        searchBy: containsIgnoreCase,
        query: 'xyz',
        scrollConfig: ListScrollConfig(controller: scrollController),
      );
      await tester.pump();

      check(find.text('No results').evaluate()).length.equals(1);
      check(scrollController.hasClients).isTrue();
    });

    scenarioWidgets('without ids, keeping its position is an error', (tester) async {
      check(
        () => ListSmith<int>.sync(
          items: const [1],
          searchBy: (_, _) => true,
          itemBuilder: (_, item, _) => Text('item $item'),
        ),
      ).throws<AssertionError>();
    });

    scenarioWidgets('without ids, a list that keeps no position still shows its rows', (
      tester,
    ) async {
      await pumpListSmith(
        tester,
        ListSmith<int>.sync(
          items: const [1, 2],
          searchBy: (_, _) => true,
          shouldKeepPosition: false,
          itemBuilder: (_, item, _) => Text('item $item'),
        ),
      );
      await tester.pump();

      check(find.textContaining('item ').evaluate()).length.equals(2);
    });

    scenarioOutlineWidgets<({List<int> firstItems, List<int>? newItems})>(
      'a repeated id is an error that names it',
      examples: {
        'in the 1st items': (firstItems: [42, 7, 42], newItems: null),
        'in new items': (firstItems: [42, 7], newItems: [42, 7, 42]),
      },
      outline: (tester, example) async {
        final itemsNotifier = ValueNotifier(example.firstItems);
        await _pumpRows(tester, itemsNotifier);
        final newItems = example.newItems;
        if (newItems != null) {
          itemsNotifier.value = newItems;
          await tester.pump();
        }

        check(tester.takeException())
            .isA<AssertionError>()
            .has((error) => '${error.message}', 'message')
            .contains('42');
      },
    );
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

    scenarioOutlineWidgets<({String fromQuery, double fromOffset, String toQuery, int topItem})>(
      'a committed query starts the list from the top',
      examples: const {
        'entering a search': (fromQuery: '', fromOffset: 1000, toQuery: '3', topItem: 3),
        // 1 and 2 match 14 items each, 100 px more than the screen.
        'changing it': (fromQuery: '1', fromOffset: 100, toQuery: '2', topItem: 2),
        'clearing it': (fromQuery: '3', fromOffset: 100, toQuery: '', topItem: 0),
      },
      outline: (tester, example) async {
        final queryNotifier = ValueNotifier(example.fromQuery);
        await _pumpSearch(tester, queryNotifier);
        tester.state<ScrollableState>(listScrollableFinder).position.jumpTo(example.fromOffset);
        await tester.pump();

        await commitQuery(tester, queryNotifier, example.toQuery);

        check(_topOf(tester, example.topItem)).equals(0);
      },
    );

    scenarioWidgets('a committed query that changes nothing keeps the place', (tester) async {
      final queryNotifier = ValueNotifier('');
      await _pumpSearch(tester, queryNotifier, minSearchLength: 2);
      tester.state<ScrollableState>(listScrollableFinder).position.jumpTo(1000);
      await tester.pump();

      // Shorter than minSearchLength, so it counts as no search, like the empty query before it.
      await commitQuery(tester, queryNotifier, '3');

      check(_topOf(tester, 20)).equals(0);
    });

    scenarioOutlineWidgets<void Function(List<_Task> tasks)>(
      'the same list coming back edited is an error',
      examples: {
        'an item added': (tasks) => tasks.insert(0, const _Task(100)),
        'an item removed': (tasks) => tasks.removeAt(1),
        // The row would keep showing the old item, since == can't tell the 2 apart.
        'an item swapped for one equal by ==': (tasks) => tasks[1] = const _Task(1),
      },
      outline: (tester, edit) async {
        final tasks = List.generate(5, _Task.new);
        late StateSetter setTasks;
        await pumpListSmith(
          tester,
          StatefulBuilder(
            builder: (_, setState) {
              setTasks = setState;

              return ListSmith<_Task>.sync(
                items: tasks,
                itemIdGetter: (task) => task.id,
                searchBy: (_, _) => true,
                itemBuilder: (_, task, _) => Text('task ${task.id}'),
              );
            },
          ),
        );

        setTasks(() => edit(tasks));
        await tester.pump();

        check(tester.takeException()).isA<AssertionError>();
      },
    );

    scenarioOutlineWidgets<({double cacheExtent, int row, bool isBuilt})>(
      'rows are built as far past the screen as the cache extent reaches',
      examples: const {
        'no cache extent, a row just past the screen': (cacheExtent: 0, row: 13, isBuilt: false),
        'a long cache extent, a row far past the screen': (
          cacheExtent: 1000,
          row: 30,
          isBuilt: true,
        ),
      },
      outline: (tester, example) async {
        await pumpListSmith(
          tester,
          ListSmith.sync(
            items: List.generate(100, (index) => 'row $index'),
            itemIdGetter: (item) => item,
            searchBy: containsIgnoreCase,
            scroll: ListScrollConfig(cacheExtent: example.cacheExtent),
            itemBuilder: (_, item, _) => SizedBox(height: 50, child: Text(item)),
          ),
        );
        await tester.pump();

        check(find.text('row ${example.row}', skipOffstage: false).evaluate()).length
            .equals(example.isBuilt ? 1 : 0);
      },
    );

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

Future<void> _pumpSync(
  WidgetTester tester, {
  required List<String> items,
  required SyncSearchPredicate<String> searchBy,
  String query = '',
  int minSearchLength = 0,
  WidgetBuilder? emptyBuilder,
  IndexedWidgetBuilder? separatorBuilder,
  ListScrollConfig scrollConfig = const ListScrollConfig(),
}) => pumpListSmith(
  tester,
  ListSmith.sync(
    items: items,
    itemIdGetter: (item) => item,
    searchBy: searchBy,
    query: query,
    minSearchLength: minSearchLength,
    emptyBuilder: emptyBuilder,
    separatorBuilder: separatorBuilder,
    scroll: scrollConfig,
    itemBuilder: (_, item, _) => Text(item),
  ),
);

typedef _RowsChange = ({
  double scrollOffset,
  List<int> Function(List<int> items, Map<int, double> heights) change,
  bool reverse,
  IndexedWidgetBuilder? separatorBuilder,
  Grouping<int>? grouping,
});

/// A `.sync` list over [itemsNotifier], keyed by value, `item N` rows 50 px tall by default.
Future<void> _pumpRows(
  WidgetTester tester,
  ValueNotifier<List<int>> itemsNotifier, {
  ScrollController? scrollController,
  bool reverse = false,
  IndexedWidgetBuilder? separatorBuilder,
  Grouping<int>? grouping,
  ItemBuilder<int>? itemBuilder,
}) => pumpListSmith(
  tester,
  ValueListenableBuilder(
    valueListenable: itemsNotifier,
    builder: (_, items, _) => ListSmith<int>.sync(
      items: items,
      itemIdGetter: (item) => item,
      searchBy: (_, _) => true,
      grouping: grouping,
      separatorBuilder: separatorBuilder,
      scroll: ListScrollConfig(controller: scrollController, reverse: reverse),
      itemBuilder: itemBuilder ?? (_, item, _) => SizedBox(height: 50, child: Text('item $item')),
    ),
  ),
);

/// A `.sync` list of `item 0` to `item 49` in 50 px rows, searched by [queryNotifier].
Future<void> _pumpSearch(
  WidgetTester tester,
  ValueNotifier<String> queryNotifier, {
  int minSearchLength = 0,
}) {
  final items = List.generate(50, (item) => item);

  return pumpListSmith(
    tester,
    ValueListenableBuilder(
      valueListenable: queryNotifier,
      builder: (_, query, _) => ListSmith<int>.sync(
        items: items,
        itemIdGetter: (item) => item,
        searchBy: (item, query) => '$item'.contains(query),
        query: query,
        minSearchLength: minSearchLength,
        itemBuilder: (_, item, _) => SizedBox(height: 50, child: Text('item $item')),
      ),
    ),
  );
}

/// An item whose `==` compares only ids, as many app models do.
@immutable
final class const _Task(final int id) {
  @override
  bool operator ==(Object other) => other is _Task && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

double _topOf(WidgetTester tester, int item) =>
    tester.getTopLeft(find.text('item $item', skipOffstage: false)).dy;

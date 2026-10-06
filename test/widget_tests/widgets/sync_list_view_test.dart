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
  WidgetBuilder? emptyBuilder,
  IndexedWidgetBuilder? separatorBuilder,
  ListScrollConfig scrollConfig = const ListScrollConfig(),
}) => pumpListSmith(
  tester,
  ListSmith.sync(
    items: items,
    searchBy: searchBy,
    query: query,
    emptyBuilder: emptyBuilder,
    separatorBuilder: separatorBuilder,
    scroll: scrollConfig,
    itemBuilder: (_, item, _) => Text(item),
  ),
);

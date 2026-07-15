import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

import '../support/bdd.dart';

void main() {
  feature('ListSmith.async surface paths', () {
    scenarioWidgets('a failing later page shows the new-page error surface', (tester) async {
      await _pumpAsync(
        tester,
        fetchPage: (pageIndex, _) async {
          if (pageIndex == 0) return const [1, 2, 3];

          throw Exception('later page');
        },
        surfaces: AsyncListSurfaces(newPageErrorBuilder: (_, _, _) => const Text('later failed')),
      );
      await _drain(tester);

      // Page 0's items stay while the failed page 1 shows its own error footer.
      check(find.text('item 1').evaluate()).length.equals(1);
      check(find.text('later failed').evaluate()).length.equals(1);
    });

    scenarioWidgets('a separator builder renders the separated list', (tester) async {
      await _pumpAsync(
        tester,
        fetchPage: (pageIndex, _) async => pageIndex == 0 ? const [1, 2, 3] : const <int>[],
        separatorBuilder: (_, _) => const Text('sep'),
      );
      await _drain(tester);

      check(find.text('item 1').evaluate()).length.equals(1);
      // Separators fall between the items (and before the end-of-list footer).
      check(find.text('sep').evaluate()).length.isGreaterThan(1);
    });
  });

  feature('ListSmith.sync rebuild and layout', () {
    scenarioWidgets('replacing the items list after build re-materialises and re-filters', (
      tester,
    ) async {
      await _pumpSync(tester, items: const ['apple', 'banana'], searchBy: _contains);
      await tester.pump();
      check(find.text('apple').evaluate()).length.equals(1);

      await _pumpSync(tester, items: const ['cherry', 'date'], searchBy: _contains);
      await tester.pump();

      check(find.text('cherry').evaluate()).length.equals(1);
      check(find.text('apple').evaluate()).length.equals(0);
    });

    scenarioWidgets('changing the query after build commits a new filter', (tester) async {
      // Same const list on both pumps, so only the query changes (isolates the query path).
      const items = ['apple', 'banana'];
      await _pumpSync(tester, items: items, searchBy: _contains);
      await tester.pump();
      check(find.text('banana').evaluate()).length.equals(1);

      await _pumpSync(tester, items: items, searchBy: _contains, query: 'app');
      // Fire the zero-duration debounce timer so the new query commits.
      await tester.pump(const Duration(milliseconds: 1));

      check(find.text('apple').evaluate()).length.equals(1);
      check(find.text('banana').evaluate()).length.equals(0);
    });

    scenarioWidgets('applies a custom cache extent', (tester) async {
      await _pumpSync(
        tester,
        items: const ['apple'],
        searchBy: _contains,
        scroll: const ListScrollConfig(cacheExtent: 250),
      );
      await tester.pump();

      check(find.text('apple').evaluate()).length.equals(1);
    });

    scenarioWidgets('a separator builder renders the separated list', (tester) async {
      await _pumpSync(
        tester,
        items: const ['apple', 'banana'],
        searchBy: _contains,
        separatorBuilder: (_, _) => const Text('sep'),
      );
      await tester.pump();

      check(find.text('apple').evaluate()).length.equals(1);
      // Two items yield one separator.
      check(find.text('sep').evaluate()).length.equals(1);
    });
  });
}

bool _contains(String item, String query) => item.toLowerCase().contains(query.toLowerCase());

Future<void> _pumpAsync(
  WidgetTester tester, {
  required PageFetcher<int> fetchPage,
  AsyncListSurfaces surfaces = const AsyncListSurfaces(),
  IndexedWidgetBuilder? separatorBuilder,
}) => tester.pumpWidget(
  Directionality(
    textDirection: .ltr,
    child: MediaQuery(
      data: const MediaQueryData(),
      child: ListSmith.async(
        fetchPage: fetchPage,
        surfaces: surfaces,
        separatorBuilder: separatorBuilder,
        pullToRefresh: false,
        itemBuilder: (_, item, _) => Text('item $item'),
      ),
    ),
  ),
);

Future<void> _pumpSync(
  WidgetTester tester, {
  required List<String> items,
  required SyncSearchPredicate<String> searchBy,
  String query = '',
  IndexedWidgetBuilder? separatorBuilder,
  ListScrollConfig scroll = const ListScrollConfig(),
}) => tester.pumpWidget(
  Directionality(
    textDirection: .ltr,
    child: MediaQuery(
      data: const MediaQueryData(),
      child: ListSmith.sync(
        items: items,
        searchBy: searchBy,
        query: query,
        separatorBuilder: separatorBuilder,
        scroll: scroll,
        itemBuilder: (_, item, _) => Text(item),
      ),
    ),
  ),
);

/// Pumps fixed frames so the first fetch, its result, and any triggered next fetch settle. The
/// neutral spinner animates forever, so we drive fixed pumps rather than `pumpAndSettle`.
Future<void> _drain(WidgetTester tester) async {
  for (var frame = 0; frame < 5; frame++) {
    await tester.pump();
  }
}

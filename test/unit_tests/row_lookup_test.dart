import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:list_smith/src/data/presentation/utils/row_lookup.dart';

void main() {
  final lookupFeature = BddFeature('Row lookup');

  // The ids are the items themselves. Read stamps don't matter to a lookup.
  RowLookup<int> lookupOver(List<List<int>> pages) => RowLookup(
    pages.map((items) => (items: items, readStamp: 0)).toList(growable: false),
    (item) => item,
  );

  Bdd(lookupFeature)
      .scenario('reads each item by its flat index, across empty pages')
      .given('pages with empty ones at the start, in the middle and at the end')
      .when('every flat index is read')
      .then('the items come back in order')
      .run((_) {
        final rowLookup = lookupOver(const [
          <int>[],
          [0, 1],
          <int>[],
          [2],
          [3, 4],
          <int>[],
        ]);

        check(List.generate(5, rowLookup.itemAt)).deepEquals(const [0, 1, 2, 3, 4]);
      });

  const pagesKey = 'pages';
  const indexKey = 'index';

  Bdd(lookupFeature)
      .scenario('finds where a row built at index 3 for item 3 sits now')
      .given('item 3 was last built at index 3')
      .when('the pages are now <$pagesKey>')
      .then('it sits at <$indexKey>')
      // Nothing moved.
      .example(
        val(pagesKey, const [
          [0, 1, 2],
          [3, 4],
        ]),
        val(indexKey, 3),
      )
      // An item landed above it.
      .example(
        val(pagesKey, const [
          [9, 0, 1],
          [2, 3, 4],
        ]),
        val(indexKey, 4),
      )
      // An item above it went.
      .example(
        val(pagesKey, const [
          [1, 2],
          [3, 4],
        ]),
        val(indexKey, 2),
      )
      // The list is now shorter than where it was.
      .example(
        val(pagesKey, const [
          [3],
        ]),
        val(indexKey, 0),
      )
      // It's gone.
      .example(
        val(pagesKey, const [
          [0, 1, 2],
          [4],
        ]),
        val(indexKey, null),
      )
      .run((context) {
        final rowLookup = lookupOver(context.example.val(pagesKey) as List<List<int>>);

        check(rowLookup.indexOf(3, 3)).equals(context.example.val(indexKey) as int?);
      });
}

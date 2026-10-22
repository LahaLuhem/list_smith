import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:list_smith/src/data/edits/edits.dart';
import 'package:list_smith/src/data/refresh/refresh.dart';

void main() {
  final lineUpFeature = BddFeature('Depth reload line-up');

  const satKey = 'sat';
  const bookedKey = 'booked';
  const readsKey = 'reads';
  const pagesKey = 'pages';

  Bdd(lineUpFeature)
      .scenario('a removal reads the page before a boundary again if it sat above it, booked after')
      .given('pages 0 and 1, sent at edits 1 and 3')
      .when('a row from <$satKey> is removed at edit <$bookedKey>')
      .then('the pages read again are <$readsKey>')
      .example(val(satKey, 'fresh page 0'), val(bookedKey, 2), val(readsKey, const [0]))
      .example(val(satKey, 'the old page 0 only'), val(bookedKey, 2), val(readsKey, const [0]))
      .example(val(satKey, 'fresh page 0'), val(bookedKey, 1), val(readsKey, const <int>[]))
      .example(val(satKey, 'fresh page 1'), val(bookedKey, 2), val(readsKey, const <int>[]))
      .example(val(satKey, 'no page, as a new item'), val(bookedKey, 2), val(readsKey, const [0]))
      .run((context) {
        final satLabel = context.example.val(satKey);
        final bookedStamp = context.example.val(bookedKey) as int;
        final removedId = switch (satLabel) {
          'fresh page 1' => 4,
          'no page, as a new item' => 100,
          _ => 1,
        };

        final rereadIndexes = resolveRereadIndexes<int>(
          oldPages: const [
            [0, 1, 2],
          ],
          freshPages: satLabel == 'the old page 0 only'
              ? const [
                  [0, 2, 3],
                  [4, 5, 6],
                ]
              : const [
                  [0, 1, 2],
                  [3, 4, 5],
                ],
          readStamps: const {0: 1, 1: 3},
          removalStamps: RemovalStamps({removedId: bookedStamp}),
          itemIdGetter: (item) => item,
          pageSize: 3,
        );

        check(rereadIndexes).deepEquals(context.example.val(readsKey) as List<int>);
      });

  Bdd(lineUpFeature)
      .scenario('removals filling more than a page read as many pages before the boundary')
      .given('3 pages of 2 rows, sent at edits 1, 2 and 3')
      .when('3 rows of pages 0 and 1 are removed at edit 4')
      .then('pages 0 and 1 are read again')
      .run((_) {
        final rereadIndexes = resolveRereadIndexes<int>(
          oldPages: const [],
          freshPages: const [
            [0, 1],
            [2, 3],
            [4, 5],
          ],
          readStamps: const {0: 1, 1: 2, 2: 3},
          removalStamps: const RemovalStamps({0: 4, 1: 4, 2: 4}),
          itemIdGetter: (item) => item,
          pageSize: 2,
        );

        check(rereadIndexes).deepEquals(const [0, 1]);
      });

  Bdd(lineUpFeature)
      .scenario(
        'each row the fresh pages lack goes in once, opening the page after the fresh row before it',
      )
      .given('fresh pages [0, 1, 2], [4, 5, 6] and [8, 9, 10]')
      .when('pages are read again as <$readsKey>')
      .then('the pages are <$pagesKey>')
      .example(
        val(readsKey, const {
          0: [0, 2, 3],
        }),
        val(pagesKey, const [
          [0, 1, 2],
          [3, 4, 5, 6],
          [8, 9, 10],
        ]),
      )
      // Opening on it, so it goes in front of that page.
      .example(
        val(readsKey, const {
          1: [3, 4, 5],
        }),
        val(pagesKey, const [
          [0, 1, 2],
          [3, 4, 5, 6],
          [8, 9, 10],
        ]),
      )
      .example(
        val(readsKey, const {
          0: [0, 2, 3],
          1: [3, 4, 5],
        }),
        val(pagesKey, const [
          [0, 1, 2],
          [3, 4, 5, 6],
          [8, 9, 10],
        ]),
      )
      // After the last fresh row, so the next page brings it.
      .example(
        val(readsKey, const {
          2: [9, 10, 11],
        }),
        val(pagesKey, const [
          [0, 1, 2],
          [4, 5, 6],
          [8, 9, 10],
        ]),
      )
      .run((context) {
        final linedUpPages = resolveLinedUpPages<int>(
          freshPages: const [
            [0, 1, 2],
            [4, 5, 6],
            [8, 9, 10],
          ],
          rereadItemsByIndex: context.example.val(readsKey) as Map<int, List<int>>,
          itemIdGetter: (item) => item,
        );

        check(linedUpPages).deepEquals(context.example.val(pagesKey) as List<List<int>>);
      });
}

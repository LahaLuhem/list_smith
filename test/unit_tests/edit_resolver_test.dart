import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:collection/collection.dart';
import 'package:list_smith/src/data/edits/typedefs/item_edit.dart';
import 'package:list_smith/src/data/edits/utils/edit_resolver.dart';
import 'package:list_smith/src/data/pagination/models/loaded_page.dart';

typedef _Row = ({int id, String label});
typedef _Placed = ({int id, int group});

void main() {
  final resolutionFeature = BddFeature('Edit resolution');

  List<String> resolveLabels(
    List<List<_Row>> pages, {
    required List<int> readStamps,
    required Map<Object, ItemEdit<_Row>> edits,
    bool acceptsNewItems = true,
  }) => resolveDisplayPages(
    pages: pages
        .mapIndexed((index, items) => LoadedPage(items: items, readStamp: readStamps[index]))
        .toList(growable: false),
    edits: edits,
    itemIdGetter: (item) => item.id,
    groupOf: null,
    acceptsNewItems: acceptsNewItems,
  ).pages.expand((page) => page.items).map((item) => item.label).toList(growable: false);

  const editKey = 'edit';
  const shownKey = 'shown';

  Bdd(resolutionFeature)
      .scenario('an edit covers a page read before it, never one read after')
      .given('page 0 read before the edits and page 1 read after')
      .when('rows 1 and 3 get <$editKey>')
      .then('the list shows <$shownKey>')
      .example(val(editKey, 'an update'), val(shownKey, const ['mine', 'b', 'c']))
      .example(val(editKey, 'a removal'), val(shownKey, const ['b', 'c']))
      .run((context) {
        final isRemoval = context.example.val(editKey) == 'a removal';
        ItemEdit<_Row> editOf(int id) =>
            (item: isRemoval ? null : (id: id, label: 'mine'), stamp: 3);

        final labels = resolveLabels(
          [
            [(id: 1, label: 'a'), (id: 2, label: 'b')],
            [(id: 3, label: 'c')],
          ],
          readStamps: const [0, 5],
          edits: {1: editOf(1), 3: editOf(3)},
        );

        check(labels).deepEquals(context.example.val(shownKey) as List<String>);
      });

  Bdd(resolutionFeature)
      .scenario('a removal hides every copy of the item, overlap duplicates included')
      .given('2 pages that both carry row 2')
      .when('row 2 is removed')
      .then('neither copy shows')
      .run((_) {
        final labels = resolveLabels(
          [
            [(id: 1, label: 'a'), (id: 2, label: 'b')],
            [(id: 2, label: 'b'), (id: 3, label: 'c')],
          ],
          readStamps: const [0, 0],
          edits: {2: (item: null, stamp: 1)},
        );

        check(labels).deepEquals(const ['a', 'c']);
      });

  Bdd(resolutionFeature)
      .scenario('new items stack on top, newest first')
      .given('a loaded page')
      .when('2 new items are added, one after the other')
      .then('the newer one sits on top')
      .run((_) {
        final labels = resolveLabels(
          [
            [(id: 1, label: 'a')],
          ],
          readStamps: const [0],
          edits: {
            8: (item: (id: 8, label: 'older'), stamp: 1),
            9: (item: (id: 9, label: 'newer'), stamp: 2),
          },
        );

        check(labels).deepEquals(const ['newer', 'older', 'a']);
      });

  const pagesKey = 'pages';

  Bdd(resolutionFeature)
      .scenario('a new item shows on top until a page has it, or every page was read after it')
      .given('a new row 9, added at edit 2')
      .when('the pages are <$pagesKey>')
      .then('the list shows <$shownKey>')
      .example(val(pagesKey, 'read before it'), val(shownKey, const ['mine', 'a']))
      .example(val(pagesKey, 'read after it'), val(shownKey, const ['a']))
      .example(val(pagesKey, 'partly read after it, with it'), val(shownKey, const ['a', 'server']))
      .run((context) {
        final (pages, readStamps) = switch (context.example.val(pagesKey)) {
          'read before it' => (
            [
              [(id: 1, label: 'a')],
            ],
            const [0],
          ),
          'read after it' => (
            [
              [(id: 1, label: 'a')],
            ],
            const [5],
          ),
          _ => (
            [
              [(id: 1, label: 'a')],
              [(id: 9, label: 'server')],
            ],
            const [0, 5],
          ),
        };

        final labels = resolveLabels(
          pages,
          readStamps: readStamps,
          edits: {9: (item: (id: 9, label: 'mine'), stamp: 2)},
        );

        check(labels).deepEquals(context.example.val(shownKey) as List<String>);
      });

  /// Adds [items] one after another, each newer than every page.
  Map<Object, ItemEdit<int>> addedInTurn(List<int> items) => Map.fromEntries(
    items.mapIndexed((index, item) => MapEntry(item, (item: item, stamp: index + 1))),
  );

  /// Resolves int pages grouped by the tens digit, every page read before the edits.
  List<int> resolveByTens(List<List<int>> pages, Map<Object, ItemEdit<int>> edits) =>
      resolveDisplayPages<int>(
        pages: pages.map((items) => LoadedPage(items: items, readStamp: 0)).toList(growable: false),
        edits: edits,
        itemIdGetter: (item) => item,
        groupOf: (item) => item ~/ 10,
        acceptsNewItems: true,
      ).pages.expand((page) => page.items).toList(growable: false);

  const loadedKey = 'loaded';
  const addedKey = 'added';

  Bdd(resolutionFeature)
      .scenario('a new item goes to the start of its group, or on top when its group is not loaded')
      .given('<$loadedKey> loaded, grouped by the tens digit')
      .when('<$addedKey> are added in turn')
      .then('the list is <$shownKey>')
      .example(
        val(loadedKey, const [0, 1, 10, 11]),
        val(addedKey, const [12, 20]),
        val(shownKey, const [20, 0, 1, 12, 10, 11]),
      )
      // 2 into one group, the newer first.
      .example(
        val(loadedKey, const [0, 1, 10, 11]),
        val(addedKey, const [12, 13]),
        val(shownKey, const [0, 1, 13, 12, 10, 11]),
      )
      // 2 groups on one page, so placing one must not shift where the other starts.
      .example(
        val(loadedKey, const [0, 1, 10, 11, 20, 21]),
        val(addedKey, const [12, 22]),
        val(shownKey, const [0, 1, 12, 10, 11, 22, 20, 21]),
      )
      .run((context) {
        final shownItems = resolveByTens([
          context.example.val(loadedKey) as List<int>,
        ], addedInTurn(context.example.val(addedKey) as List<int>));

        check(shownItems).deepEquals(context.example.val(shownKey) as List<int>);
      });

  Bdd(resolutionFeature)
      .scenario(
        'new items of a group that is not loaded yet stay together, the newest group on top',
      )
      .given('groups 0 and 1 loaded, grouped by the tens digit')
      .when('30, 40 and then 31 are added')
      .then('31 joins 30 under the newer group 4')
      .run((_) {
        final shownItems = resolveByTens(const [
          [0, 1, 10, 11],
        ], addedInTurn(const [30, 40, 31]));

        check(shownItems).deepEquals(const [40, 31, 30, 0, 1, 10, 11]);
      });

  Bdd(resolutionFeature)
      .scenario("an edit that changes an item's group moves it to the start of that group")
      .given('items 0 and 1 in group 0, items 10 and 11 in group 1')
      .when('item 0 is edited into group 1')
      .then('it leaves group 0 and opens group 1')
      .run((_) {
        final pages = resolveDisplayPages<_Placed>(
          pages: const [
            LoadedPage(
              items: [(id: 0, group: 0), (id: 1, group: 0), (id: 10, group: 1), (id: 11, group: 1)],
              readStamp: 0,
            ),
          ],
          edits: {0: (item: (id: 0, group: 1), stamp: 1)},
          itemIdGetter: (item) => item.id,
          groupOf: (item) => item.group,
          acceptsNewItems: true,
        ).pages;

        check(pages.expand((page) => page.items).map((item) => item.id).toList())
            .deepEquals(const [1, 0, 10, 11]);
      });

  Bdd(resolutionFeature)
      .scenario('while searching, a new item stays out but edits to results still apply')
      .given('search results, rows 1 and 2')
      .when('row 1 is edited, row 2 removed and a new row 9 added')
      .then('only the edited row 1 shows')
      .run((_) {
        final labels = resolveLabels(
          [
            [(id: 1, label: 'a'), (id: 2, label: 'b')],
          ],
          readStamps: const [0],
          edits: {
            1: (item: (id: 1, label: 'mine'), stamp: 1),
            2: (item: null, stamp: 2),
            9: (item: (id: 9, label: 'new'), stamp: 3),
          },
          acceptsNewItems: false,
        );

        check(labels).deepEquals(const ['mine']);
      });

  Bdd(resolutionFeature)
      .scenario('overlap duplicates stay hidden while edits are in play')
      .given('2 pages that both carry row 2')
      .when('row 1 is edited')
      .then('row 2 still shows once')
      .run((_) {
        final labels = resolveLabels(
          [
            [(id: 1, label: 'a'), (id: 2, label: 'b')],
            [(id: 2, label: 'b'), (id: 3, label: 'c')],
          ],
          readStamps: const [0, 0],
          edits: {1: (item: (id: 1, label: 'mine'), stamp: 1)},
        );

        check(labels).deepEquals(const ['mine', 'b', 'c']);
      });

  const changeKey = 'change';
  const editsKey = 'edits';
  const acceptsNewItemsKey = 'acceptsNewItems';
  const shownIdsKey = 'shownIds';

  Bdd(resolutionFeature)
      .scenario('the ids it reports are the ids it shows')
      .given('items 0 and 1 in group 0, items 10 and 11 in group 1, read before the edits')
      .when('<$changeKey> comes in')
      .then('it reports <$shownIdsKey>, the ids on its pages')
      .example(
        val(changeKey, 'a new item'),
        val(editsKey, const <Object, ItemEdit<_Placed>>{12: (item: (id: 12, group: 1), stamp: 1)}),
        val(acceptsNewItemsKey, true),
        val(shownIdsKey, const [0, 1, 10, 11, 12]),
      )
      .example(
        val(changeKey, 'a new item while searching'),
        val(editsKey, const <Object, ItemEdit<_Placed>>{12: (item: (id: 12, group: 1), stamp: 1)}),
        val(acceptsNewItemsKey, false),
        val(shownIdsKey, const [0, 1, 10, 11]),
      )
      .example(
        val(changeKey, 'a removal'),
        val(editsKey, const <Object, ItemEdit<_Placed>>{1: (item: null, stamp: 1)}),
        val(acceptsNewItemsKey, true),
        val(shownIdsKey, const [0, 10, 11]),
      )
      .example(
        val(changeKey, 'a move to another group'),
        val(editsKey, const <Object, ItemEdit<_Placed>>{0: (item: (id: 0, group: 1), stamp: 1)}),
        val(acceptsNewItemsKey, true),
        val(shownIdsKey, const [0, 1, 10, 11]),
      )
      .run((context) {
        final (:pages, :shownIds) = resolveDisplayPages<_Placed>(
          pages: const [
            LoadedPage(
              items: [(id: 0, group: 0), (id: 1, group: 0), (id: 10, group: 1), (id: 11, group: 1)],
              readStamp: 0,
            ),
          ],
          edits: context.example.val(editsKey) as Map<Object, ItemEdit<_Placed>>,
          itemIdGetter: (item) => item.id,
          groupOf: (item) => item.group,
          acceptsNewItems: context.example.val(acceptsNewItemsKey) as bool,
        );

        check(shownIds).unorderedEquals(pages.expand((page) => page.items).map((item) => item.id));
        check(shownIds).unorderedEquals(context.example.val(shownIdsKey) as List<int>);
      });
}

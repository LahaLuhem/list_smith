import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:list_smith/list_smith.dart';
import 'package:list_smith/src/data/edits/typedefs/item_edit.dart';
import 'package:list_smith/src/data/edits/utils/edit_resolver.dart';

typedef _Row = ({int id, String label});
typedef _Placed = ({int id, int group});

void main() {
  final resolution = BddFeature('Edit resolution');

  List<String> resolveLabels(
    List<List<_Row>> pages, {
    required List<int> readStamps,
    required Map<Object, ItemEdit<_Row>> edits,
    bool acceptsNewItems = true,
  }) => resolveDisplayPages(
    pages: pages,
    readStamps: readStamps,
    edits: edits,
    itemId: (item) => item.id,
    grouping: const NoGrouping<_Row>(),
    acceptsNewItems: acceptsNewItems,
  ).flattened.map((item) => item.label).toList(growable: false);

  const editKey = 'edit';
  const shownKey = 'shown';

  Bdd(resolution)
      .scenario('an edit covers a page read before it, never one read after')
      .given('page 0 read before the edits and page 1 read after')
      .when('rows 1 and 3 get <$editKey>')
      .then('the list shows <$shownKey>')
      .example(val(editKey, 'an update'), val(shownKey, const ['mine', 'b', 'c']))
      .example(val(editKey, 'a removal'), val(shownKey, const ['b', 'c']))
      .run((ctx) {
        final isRemoval = ctx.example.val(editKey) == 'a removal';
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

        check(labels).deepEquals(ctx.example.val(shownKey) as List<String>);
      });

  Bdd(resolution)
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

  Bdd(resolution)
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

  Bdd(resolution)
      .scenario('a new item shows on top until a page has it, or every page was read after it')
      .given('a new row 9, added at edit 2')
      .when('the pages are <$pagesKey>')
      .then('the list shows <$shownKey>')
      .example(val(pagesKey, 'read before it'), val(shownKey, const ['mine', 'a']))
      .example(val(pagesKey, 'read after it'), val(shownKey, const ['a']))
      .example(val(pagesKey, 'partly read after it, with it'), val(shownKey, const ['a', 'server']))
      .run((ctx) {
        final (pages, readStamps) = switch (ctx.example.val(pagesKey)) {
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

        check(labels).deepEquals(ctx.example.val(shownKey) as List<String>);
      });

  Bdd(resolution)
      .scenario('a new item goes to the start of its group, or on top when its group is not loaded')
      .given('groups 0 and 1 loaded, grouped by the tens digit')
      .when('12 and then 20 are added')
      .then('12 opens group 1 and 20 opens a group of its own on top')
      .run((_) {
        final pages = resolveDisplayPages<int>(
          pages: const [
            [0, 1, 10, 11],
          ],
          readStamps: const [0],
          edits: {12: (item: 12, stamp: 1), 20: (item: 20, stamp: 2)},
          itemId: (item) => item,
          grouping: Grouping.by(
            groupBy: (item) => item ~/ 10,
            headerBuilder: (_, key) => Text('group $key'),
          ),
          acceptsNewItems: true,
        );

        check(pages.flattened.toList()).deepEquals(const [20, 0, 1, 12, 10, 11]);
      });

  Bdd(resolution)
      .scenario("an edit that changes an item's group moves it to the start of that group")
      .given('items 0 and 1 in group 0, items 10 and 11 in group 1')
      .when('item 0 is edited into group 1')
      .then('it leaves group 0 and opens group 1')
      .run((_) {
        final pages = resolveDisplayPages<_Placed>(
          pages: const [
            [(id: 0, group: 0), (id: 1, group: 0), (id: 10, group: 1), (id: 11, group: 1)],
          ],
          readStamps: const [0],
          edits: {0: (item: (id: 0, group: 1), stamp: 1)},
          itemId: (item) => item.id,
          grouping: Grouping.by(
            groupBy: (item) => item.group,
            headerBuilder: (_, key) => Text('group $key'),
          ),
          acceptsNewItems: true,
        );

        check(pages.flattened.map((item) => item.id).toList()).deepEquals(const [1, 0, 10, 11]);
      });

  Bdd(resolution)
      .scenario('while searching, a new item stays out but an edit to a result still shows')
      .given('a search result, row 1')
      .when('row 1 is edited and a new row 9 is added')
      .then('only the edited row 1 shows')
      .run((_) {
        final labels = resolveLabels(
          [
            [(id: 1, label: 'a')],
          ],
          readStamps: const [0],
          edits: {
            1: (item: (id: 1, label: 'mine'), stamp: 1),
            9: (item: (id: 9, label: 'new'), stamp: 2),
          },
          acceptsNewItems: false,
        );

        check(labels).deepEquals(const ['mine']);
      });

  Bdd(resolution)
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
}

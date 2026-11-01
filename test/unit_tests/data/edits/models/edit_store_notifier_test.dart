import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:flutter/foundation.dart';
import 'package:list_smith/src/data/edits/edits.dart';
import 'package:list_smith/src/data/pagination/pagination.dart';

typedef _Row = ({int id, String label});

void main() {
  final storeFeature = BddFeature('Edit store');

  List<String> shownLabels(
    EditStoreNotifier<_Row> editStoreNotifier,
    List<_Row> rows, {
    required int readStamp,
  }) => editStoreNotifier
      .applyTo(
        [LoadedPage(items: rows, readStamp: readStamp)],
        itemIdGetter: (item) => item.id,
        groupOf: null,
        acceptsNewItems: true,
        sortedPlacement: null,
      )
      .pages
      .expand((page) => page.items)
      .map((item) => item.label)
      .toList(growable: false);

  PendingEdit<_Row> draftOut(EditStoreNotifier<_Row> editStoreNotifier, String label) =>
      editStoreNotifier.pendingEdit(1, (id: 1, label: label))..book();

  const readOffsetsKey = 'read offsets';
  const isKeptKey = 'is kept';

  Bdd(storeFeature)
      .scenario('an edit stays while any page was read before it')
      .given('an edit, and pages read at <$readOffsetsKey> from it')
      .when('the store drops what those pages caught up with')
      .then('the edit is kept: <$isKeptKey>')
      .example(val(readOffsetsKey, const [-1, 0]), val(isKeptKey, true))
      .example(val(readOffsetsKey, const [0, 1]), val(isKeptKey, false))
      .run((context) {
        final editStoreNotifier = EditStoreNotifier<int>()..book(1, 10);
        final editStamp = editStoreNotifier.value;
        final readOffsets = context.example.val(readOffsetsKey) as List<int>;

        editStoreNotifier.dropCaughtUp(readOffsets.map((offset) => editStamp + offset));

        check(editStoreNotifier.isEmpty).equals(!(context.example.val(isKeptKey) as bool));
        editStoreNotifier.dispose();
      });

  Bdd(storeFeature)
      .scenario("a save's answer takes its draft's place, newest first")
      .given('2 new items whose saves are out, 8 booked after 7')
      .when("7's save answers")
      .then('7 shows what the save gave back, still under 8')
      .run((_) {
        final editStoreNotifier = EditStoreNotifier<_Row>();
        final pendingEdit = editStoreNotifier.pendingEdit(7, (id: 7, label: '7 draft'))..book();
        editStoreNotifier.pendingEdit(8, (id: 8, label: '8 draft')).book();

        pendingEdit.settle((id: 7, label: '7 saved'));

        check(shownLabels(editStoreNotifier, [(id: 1, label: 'a')], readStamp: 0))
            .deepEquals(['8 draft', '7 saved', 'a']);
        editStoreNotifier.dispose();
      });

  const coveredKey = 'covered';
  const editsKey = 'edits';
  const shownKey = 'shown';

  Bdd(storeFeature)
      .scenario('a failed draft brings back what it covered')
      .given('item 1 as the server sent it, under <$coveredKey>')
      .when("a draft's save fails")
      .then('the item shows <$shownKey>')
      .example(
        val(coveredKey, 'a booked edit'),
        val(editsKey, (EditStoreNotifier<_Row> editStoreNotifier) {
          editStoreNotifier.book(1, (id: 1, label: 'booked'));
          draftOut(editStoreNotifier, 'draft').drop();
        }),
        val(shownKey, const ['booked']),
      )
      .example(
        val(coveredKey, 'an older draft still out'),
        val(editsKey, (EditStoreNotifier<_Row> editStoreNotifier) {
          draftOut(editStoreNotifier, 'older');
          draftOut(editStoreNotifier, 'newer').drop();
        }),
        val(shownKey, const ['older']),
      )
      .example(
        val(coveredKey, 'nothing, with a newer draft out over it'),
        val(editsKey, (EditStoreNotifier<_Row> editStoreNotifier) {
          final olderPendingEdit = draftOut(editStoreNotifier, 'older');
          draftOut(editStoreNotifier, 'newer');
          olderPendingEdit.drop();
        }),
        val(shownKey, const ['newer']),
      )
      .example(
        val(coveredKey, 'nothing, with a newer save that answered'),
        val(editsKey, (EditStoreNotifier<_Row> editStoreNotifier) {
          final olderPendingEdit = draftOut(editStoreNotifier, 'older');
          draftOut(editStoreNotifier, 'newer').settle((id: 1, label: 'newer saved'));
          olderPendingEdit.drop();
        }),
        val(shownKey, const ['newer saved']),
      )
      .example(
        val(coveredKey, 'an older save that answered'),
        val(editsKey, (EditStoreNotifier<_Row> editStoreNotifier) {
          final olderPendingEdit = draftOut(editStoreNotifier, 'older');
          final newerPendingEdit = draftOut(editStoreNotifier, 'newer');
          olderPendingEdit.settle((id: 1, label: 'older saved'));
          newerPendingEdit.drop();
        }),
        val(shownKey, const ['older saved']),
      )
      .run((context) {
        final editStoreNotifier = EditStoreNotifier<_Row>();
        final applyEdits = context.example.val(editsKey) as ValueSetter<EditStoreNotifier<_Row>>;

        applyEdits(editStoreNotifier);

        check(shownLabels(editStoreNotifier, [(id: 1, label: 'a')], readStamp: 0))
            .deepEquals(context.example.val(shownKey) as List<String>);
        editStoreNotifier.dispose();
      });

  Bdd(storeFeature)
      .scenario('a failed re-edit puts a new item back in its slot')
      .given('new items 7 then 8, so 8 shows on top')
      .when('a draft of 7 lifts it on top, and its save fails')
      .then('7 goes back under 8')
      .run((_) {
        final editStoreNotifier = EditStoreNotifier<_Row>()
          ..book(7, (id: 7, label: '7'))
          ..book(8, (id: 8, label: '8'));
        final pendingEdit = editStoreNotifier.pendingEdit(7, (id: 7, label: '7 renamed'))..book();
        check(shownLabels(editStoreNotifier, const [], readStamp: 0))
            .deepEquals(['7 renamed', '8']);

        pendingEdit.drop();

        check(shownLabels(editStoreNotifier, const [], readStamp: 0)).deepEquals(['8', '7']);
        editStoreNotifier.dispose();
      });

  const outcomeKey = 'outcome';
  const answerKey = 'answer';
  const shownBeforeKey = 'shown before';
  const shownAfterKey = 'shown after';

  Bdd(storeFeature)
      .scenario('a draft booked after its save answered shows only that answer, as settled')
      .given('item 1 as the server sent it, and a draft of it whose save <$outcomeKey>')
      .when('the draft is booked')
      .then('a page read before shows <$shownBeforeKey>, and one read after shows <$shownAfterKey>')
      .example(
        val(outcomeKey, 'answered'),
        val(
          answerKey,
          (PendingEdit<_Row> pendingEdit) => pendingEdit.settle((id: 1, label: 'saved')),
        ),
        val(shownBeforeKey, const ['saved']),
        val(shownAfterKey, const ['a']),
      )
      .example(
        val(outcomeKey, 'failed'),
        val(answerKey, (PendingEdit<_Row> pendingEdit) => pendingEdit.drop()),
        val(shownBeforeKey, const ['a']),
        val(shownAfterKey, const ['a']),
      )
      .run((context) {
        final editStoreNotifier = EditStoreNotifier<_Row>();
        final pendingEdit = editStoreNotifier.pendingEdit(1, (id: 1, label: 'draft'));
        (context.example.val(answerKey) as ValueSetter<PendingEdit<_Row>>)(pendingEdit);
        final beforeStamp = editStoreNotifier.value;

        pendingEdit.book();

        check(shownLabels(editStoreNotifier, [(id: 1, label: 'a')], readStamp: beforeStamp))
            .deepEquals(context.example.val(shownBeforeKey) as List<String>);
        check(
          shownLabels(editStoreNotifier, [(id: 1, label: 'a')], readStamp: editStoreNotifier.value),
        ).deepEquals(context.example.val(shownAfterKey) as List<String>);
        editStoreNotifier.dispose();
      });
}

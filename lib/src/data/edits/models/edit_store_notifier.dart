import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '/src/data/grouping/typedefs/group_key_of.dart';
import '/src/data/pagination/models/loaded_page.dart';
import '/src/data/pagination/typedefs/item_id_getter.dart';
import '../typedefs/item_edit.dart';
import '../utils/edit_resolver.dart';

/// The local edits, kept beside the loaded pages rather than in them, so the end policy and the reloads
/// keep reading what the server sent.
///
/// Every change that shows moves its value, since the display memo keys on it.
final class EditStoreNotifier<T extends Object>()
    extends ChangeNotifier
    implements ValueListenable<int> {
  /// Per item, oldest edit first.
  final _bookedEditsById = <Object, List<_BookedEdit<T>>>{};

  Map<Object, ItemEdit<T>>? _newestItemEditsById;

  var _stamp = 0;

  /// Creates it.
  this;

  /// The edit counter. A page read stamps itself with it, so an edit made after is newer.
  @override
  int get value => _stamp;

  /// Whether there's nothing to apply.
  bool get isEmpty => _bookedEditsById.isEmpty;

  int get _nextStamp => _stamp + 1;

  /// An edit the server already has, so it wins over any still out. Null removes.
  void book(Object itemId, T? editedItem) {
    _bookedEditsById
      ..remove(itemId) // re-booked at the end, so the newest new item lands on top
      ..[itemId] = [_BookedEdit(item: editedItem, stamp: _nextStamp, bookedAt: _nextStamp)];

    _moveOn();
  }

  /// Shows [editedItem] until [commit] answers, then the answer. A failure brings back what it covered.
  Future<R> bookPending<R extends T?>(Object itemId, T? editedItem, Future<R> commit) async {
    final pendingBookedEdit = _BookedEdit(
      item: editedItem,
      stamp: _pendingStamp,
      bookedAt: _nextStamp,
    );
    _bookedEditsById[itemId] = (_bookedEditsById.remove(itemId) ?? [])..add(pendingBookedEdit);

    _moveOn();

    try {
      final answeredItem = await commit;
      _settle(itemId, pendingBookedEdit, answeredItem);

      return answeredItem;
    } finally {
      _drop(itemId, pendingBookedEdit); // a no-op once settled
    }
  }

  /// Drops the edits every page in [readStamps] was read after, since the server's copy has caught up.
  void dropCaughtUp(Iterable<int> readStamps) {
    if (readStamps.isEmpty) return;

    final oldestReadStamp = readStamps.min;
    for (final bookedEdits in _bookedEditsById.values) {
      bookedEdits.removeWhere((bookedEdit) => bookedEdit.stamp <= oldestReadStamp);
    }
    _bookedEditsById.removeWhere((_, bookedEdits) => bookedEdits.isEmpty);
    // Nothing dropped here still shows, so the value stays put.
    _newestItemEditsById = null;
  }

  /// Drops every edit, pending ones too.
  void clear() {
    if (_bookedEditsById.isEmpty) return;

    _bookedEditsById.clear();

    _moveOn();
  }

  /// [pages] as they render, edits applied, and the ids in them.
  ({List<LoadedPage<T>> pages, Set<Object> shownIds}) applyTo(
    List<LoadedPage<T>> pages, {
    required ItemIdGetter<T> itemIdGetter,
    required GroupKeyOf<T, Object>? groupOf,
    required bool acceptsNewItems,
  }) => resolveDisplayPages(
    pages: pages,
    edits: _newestItemEditsById ??= _bookedEditsById.map(
      (itemId, bookedEdits) =>
          MapEntry(itemId, (item: bookedEdits.last.item, stamp: bookedEdits.last.stamp)),
    ),
    itemIdGetter: itemIdGetter,
    groupOf: groupOf,
    acceptsNewItems: acceptsNewItems,
  );

  @override
  void dispose() {
    _bookedEditsById.clear(); // so a late answer finds nothing
    super.dispose();
  }

  void _settle(Object itemId, _BookedEdit<T> pendingBookedEdit, T? answeredItem) {
    final bookedEdits = _bookedEditsById[itemId];
    if (bookedEdits == null) return;
    final index = bookedEdits.indexOf(pendingBookedEdit);
    if (index < 0) return;

    bookedEdits
      ..[index] = _BookedEdit(
        item: answeredItem,
        stamp: _nextStamp,
        bookedAt: pendingBookedEdit.bookedAt,
      )
      ..removeRange(0, index); // nothing under a settled edit shows again

    _moveOn();
  }

  void _drop(Object itemId, _BookedEdit<T> pendingBookedEdit) {
    final bookedEdits = _bookedEditsById[itemId];
    if (bookedEdits == null) return;
    final index = bookedEdits.indexOf(pendingBookedEdit);
    if (index < 0) return;

    bookedEdits.removeAt(index);
    if (bookedEdits.isEmpty) {
      _bookedEditsById.remove(itemId);
    } else if (index == bookedEdits.length) {
      // Was the newest, so back to the older edit's slot.
      final reorderedEntries = _bookedEditsById.entries.sortedBy<num>(
        (entry) => entry.value.last.bookedAt,
      );
      _bookedEditsById
        ..clear()
        ..addEntries(reorderedEntries);
    }

    _moveOn();
  }

  /// Callers stamp with [_nextStamp] first.
  void _moveOn() {
    _stamp++;
    _newestItemEditsById = null;
    notifyListeners();
  }

  /// After every read. The web's largest exact int.
  static const _pendingStamp = 0x1FFFFFFFFFFFFF;
}

/// [bookedAt] orders the items' slots.
final class _BookedEdit<T extends Object>({
  required final T? item,
  required final int stamp,
  required final int bookedAt,
});

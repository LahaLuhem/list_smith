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
  /// The latest edit per item id, oldest first.
  final _itemEditsById = <Object, ItemEdit<T>>{};

  var _stamp = 0;

  /// Creates it.
  this;

  /// The edit counter. A page read stamps itself with it, so an edit made after is newer.
  @override
  int get value => _stamp;

  /// Whether there's nothing to apply.
  bool get isEmpty => _itemEditsById.isEmpty;

  /// Books [editedItem] against [itemId], null for a removal.
  void book(Object itemId, T? editedItem) {
    _stamp++;
    _itemEditsById
      ..remove(itemId) // re-booked at the end, so the newest new item lands on top
      ..[itemId] = (item: editedItem, stamp: _stamp);

    notifyListeners();
  }

  /// Drops the edits every page in [readStamps] was read after, since the server's copy has caught up.
  void dropCaughtUp(Iterable<int> readStamps) {
    if (readStamps.isEmpty) return;

    final oldestReadStamp = readStamps.min;
    // Nothing dropped here still shows, so the value stays put.
    _itemEditsById.removeWhere((_, edit) => edit.stamp <= oldestReadStamp);
  }

  /// [pages] as they render, edits applied, and the ids in them.
  ({List<LoadedPage<T>> pages, Set<Object> shownIds}) applyTo(
    List<LoadedPage<T>> pages, {
    required ItemIdGetter<T> itemIdGetter,
    required GroupKeyOf<T, Object>? groupOf,
    required bool acceptsNewItems,
  }) => resolveDisplayPages(
    pages: pages,
    edits: _itemEditsById,
    itemIdGetter: itemIdGetter,
    groupOf: groupOf,
    acceptsNewItems: acceptsNewItems,
  );
}

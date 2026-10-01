import 'package:collection/collection.dart';

import '/src/data/grouping/typedefs/group_key_of.dart';
import '/src/data/pagination/typedefs/item_id_getter.dart';
import '../typedefs/item_edit.dart';

/// The start given to a group that isn't loaded, whose items open on top instead.
const _opensOnTop = -1;

/// The pages as they render, edits applied, and the ids in them. An edit only covers a page read
/// before it, since a page read after already has the server's answer. [edits] runs oldest to newest.
({List<List<T>> pages, Set<Object> shownIds}) resolveDisplayPages<T extends Object>({
  required List<List<T>> pages,
  required List<int> readStamps,
  required Map<Object, ItemEdit<T>> edits,
  required ItemIdGetter<T> itemIdGetter,
  required GroupKeyOf<T, Object>? groupOf,
  required bool acceptsNewItems,
}) {
  final shownIds = <Object>{};
  final movedIds = <Object>{};
  final displayPages = <List<T>>[];

  // A loop, like the other per-item scans on the build path (APPENDIX.md#scan-loops).
  for (var pageIndex = 0; pageIndex < pages.length; pageIndex++) {
    final readStamp = readStamps[pageIndex];
    final displayPage = <T>[];
    for (final item in pages[pageIndex]) {
      final id = itemIdGetter(item);
      final edit = edits[id];
      if (edit == null || edit.stamp <= readStamp) {
        if (shownIds.add(id)) displayPage.add(item);
        continue;
      }

      final editedItem = edit.item;
      // A fresher copy further down still shows.
      if (editedItem == null || !shownIds.add(id)) continue;
      if (groupOf == null || groupOf(item) == groupOf(editedItem)) {
        displayPage.add(editedItem);
      } else {
        movedIds.add(id);
      }
    }
    displayPages.add(displayPage);
  }
  if (displayPages.isEmpty) return (pages: displayPages, shownIds: shownIds);

  // A new item shows while some page predates it. Once none does, the server's answer is in.
  final oldestRead = readStamps.min;
  bool isNew(Object id, ItemEdit<T> edit) =>
      acceptsNewItems && !shownIds.contains(id) && edit.stamp > oldestRead;
  final toPlace = edits.entries
      .where((entry) => movedIds.contains(entry.key) || isNew(entry.key, entry.value))
      .map((entry) => entry.value.item)
      .nonNulls // a removal has nothing to place
      .toList(growable: false);
  if (toPlace.isNotEmpty) {
    _placeAll(displayPages, toPlace, groupOf);
    shownIds.addAll(toPlace.map(itemIdGetter)); // the new ones weren't on a page
  }

  return (pages: displayPages, shownIds: shownIds);
}

/// Puts [items], oldest first, where inserting them one by one would: each at the start of its group,
/// newest first, and a group that isn't loaded opening on top, the one opened last highest.
void _placeAll<T extends Object>(
  List<List<T>> pages,
  List<T> items,
  GroupKeyOf<T, Object>? groupOf,
) {
  if (groupOf == null) {
    pages.first.insertAll(0, items.reversed);

    return;
  }

  final starts = _groupStarts(pages, items.map(groupOf).toSet(), groupOf);
  final byStart = items.groupListsBy((item) => starts[groupOf(item)] ?? _opensOnTop);
  final openingGroups = (byStart.remove(_opensOnTop) ?? []).groupListsBy(groupOf);
  // The last start first, so an insert can't shift the starts still to come.
  final joinings = byStart.entries.sorted((a, b) => b.key.compareTo(a.key));
  for (final MapEntry(key: start, value: joiners) in joinings) {
    _insertAt(pages, start, joiners.reversed);
  }
  pages.first.insertAll(
    0,
    openingGroups.values.toList().reversed.expand((group) => group.reversed),
  );
}

/// The flat index where each group in [needed] first shows. Stops once it has them all.
Map<Object, int> _groupStarts<T extends Object>(
  List<List<T>> pages,
  Set<Object> needed,
  GroupKeyOf<T, Object> groupOf,
) {
  final starts = <Object, int>{};
  var flatIndex = 0;
  // A loop, like the other per-item scans on the build path (APPENDIX.md#scan-loops).
  for (final page in pages) {
    for (final item in page) {
      final key = groupOf(item);
      if (needed.contains(key)) starts[key] ??= flatIndex;
      if (starts.length == needed.length) return starts;
      flatIndex++;
    }
  }

  return starts;
}

/// Turns a flat [index] into a page and an offset.
void _insertAt<T extends Object>(List<List<T>> pages, int index, Iterable<T> items) {
  var offset = index;
  for (final page in pages) {
    if (offset <= page.length) {
      page.insertAll(offset, items);

      return;
    }
    offset -= page.length;
  }
}

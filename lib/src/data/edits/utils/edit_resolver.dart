import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '/src/data/grouping/typedefs/group_key_of.dart';
import '/src/data/pagination/models/loaded_page.dart';
import '/src/data/pagination/typedefs/item_id_getter.dart';
import '../models/item_edit.dart';

/// The start given to a group that isn't loaded, whose items open on top instead.
const _opensOnTop = -1;

/// The server's order, and whether rows may follow the loaded ones.
@internal
typedef SortedPlacement<T extends Object> = ({Comparator<T> comparator, bool mayHaveRowsAfter});

/// The pages as they render, edits applied, and the ids in them. An edit only covers a page read
/// before it, since a page read after already has the server's answer. [edits] runs oldest to newest.
/// With [sortedPlacement], an edit that moves its row and a new item go where the order puts them.
@internal
({List<LoadedPage<T>> pages, Set<Object> shownIds}) resolveDisplayPages<T extends Object>({
  required List<LoadedPage<T>> pages,
  required Map<Object, ItemEdit<T>> edits,
  required ItemIdGetter<T> itemIdGetter,
  required GroupKeyOf<T, Object>? groupOf,
  required bool acceptsNewItems,
  SortedPlacement<T>? sortedPlacement,
}) {
  final comparator = sortedPlacement?.comparator;
  final shownIds = <Object>{};
  final movedIds = <Object>{};
  final displayPages = <LoadedPage<T>>[];

  // A loop, like the other per-item scans on the build path (APPENDIX.md#scan-loops).
  for (final page in pages) {
    final displayPage = <T>[];
    for (final item in page.items) {
      final id = itemIdGetter(item);
      final edit = edits[id];
      if (edit == null || edit.stamp <= page.readStamp) {
        if (shownIds.add(id)) displayPage.add(item);
        continue;
      }

      final editedItem = edit.item;
      if (comparator != null) {
        // Placed later, so a page read after the edit still shows the server's copy.
        if (editedItem == null || shownIds.contains(id) || movedIds.contains(id)) continue;
        if (comparator(item, editedItem) == 0) {
          shownIds.add(id);
          displayPage.add(editedItem);
        } else {
          movedIds.add(id);
        }
        continue;
      }
      // A fresher copy further down still shows.
      if (editedItem == null || !shownIds.add(id)) continue;
      if (groupOf == null || groupOf(item) == groupOf(editedItem)) {
        displayPage.add(editedItem);
      } else {
        movedIds.add(id);
      }
    }
    displayPages.add(
      LoadedPage(
        items: displayPage,
        readStamp: page.readStamp,
        previousSignal: page.previousSignal,
      ),
    );
  }
  if (displayPages.isEmpty) return (pages: displayPages, shownIds: shownIds);

  // A new item shows while some page predates it. Once none does, the server's answer is in.
  final oldestRead = pages.map((page) => page.readStamp).min;
  bool isNew(Object id, ItemEdit<T> edit) =>
      acceptsNewItems && !shownIds.contains(id) && edit.stamp > oldestRead;
  if (sortedPlacement != null) {
    final placedItems = edits.entries
        .where(
          (entry) =>
              !shownIds.contains(entry.key) &&
              (movedIds.contains(entry.key) || isNew(entry.key, entry.value)),
        )
        .map((entry) => entry.value.item)
        .nonNulls
        .toList(growable: false);
    for (final item in placedItems) {
      // Pages run in order, so its spot is in the 1st one that doesn't end before it.
      final page = displayPages.firstWhereOrNull(
        (page) => page.items.isNotEmpty && sortedPlacement.comparator(page.items.last, item) >= 0,
      );
      if (page != null) {
        page.items.insert(lowerBound(page.items, item, compare: sortedPlacement.comparator), item);
      } else if (sortedPlacement.mayHaveRowsAfter) {
        continue; // it belongs to a page not loaded yet
      } else {
        displayPages.last.items.add(item);
      }
      shownIds.add(itemIdGetter(item));
    }

    return (pages: displayPages, shownIds: shownIds);
  }
  final toPlace = edits.entries
      .where((entry) => movedIds.contains(entry.key) || isNew(entry.key, entry.value))
      .map((entry) => entry.value.item)
      .nonNulls // a removal has nothing to place
      .toList(growable: false);
  if (toPlace.isNotEmpty) {
    // Oldest first, where inserting one by one would put each: at the start of its group, newest first,
    // and a group that isn't loaded opening on top, the one opened last highest.
    if (groupOf == null) {
      displayPages.first.items.insertAll(0, toPlace.reversed);
    } else {
      final neededKeys = toPlace.map(groupOf).toSet();
      final starts = <Object, int>{};
      var flatIndex = 0;
      // A loop, like the other per-item scans on the build path (APPENDIX.md#scan-loops).
      scan:
      for (final page in displayPages) {
        for (final item in page.items) {
          final key = groupOf(item);
          if (neededKeys.contains(key)) starts[key] ??= flatIndex;
          if (starts.length == neededKeys.length) break scan;
          flatIndex++;
        }
      }
      final byStart = toPlace.groupListsBy((item) => starts[groupOf(item)] ?? _opensOnTop);
      final openingGroups = (byStart.remove(_opensOnTop) ?? []).groupListsBy(groupOf);
      // The last start first, so an insert can't shift the starts still to come.
      final joinings = byStart.entries.sorted((a, b) => b.key.compareTo(a.key));
      for (final MapEntry(key: start, value: joiners) in joinings) {
        var offset = start;
        for (final page in displayPages) {
          if (offset <= page.items.length) {
            page.items.insertAll(offset, joiners.reversed);
            break;
          }
          offset -= page.items.length;
        }
      }
      displayPages.first.items.insertAll(
        0,
        openingGroups.values.toList().reversed.expand((group) => group.reversed),
      );
    }
    shownIds.addAll(toPlace.map(itemIdGetter)); // the new ones weren't on a page
  }

  return (pages: displayPages, shownIds: shownIds);
}

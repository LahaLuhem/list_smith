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
  final (:displayPages, :shownIds, :movedIds) = _applyEdits(
    pages,
    edits: edits,
    itemIdGetter: itemIdGetter,
    groupOf: groupOf,
    comparator: sortedPlacement?.comparator,
  );
  if (displayPages.isEmpty) return (pages: displayPages, shownIds: shownIds);

  // A new item shows while some page predates it. Once none does, the server's answer is in.
  final oldestRead = pages.map((page) => page.readStamp).min;
  final placingItems = edits.entries
      .where(
        (entry) =>
            !shownIds.contains(entry.key) &&
            (movedIds.contains(entry.key) || (acceptsNewItems && entry.value.stamp > oldestRead)),
      )
      .map((entry) => entry.value.item)
      .nonNulls // a removal has nothing to place
      .toList(growable: false);
  final placedItems = sortedPlacement == null
      ? _placeAtGroupStarts(displayPages, placingItems, groupOf)
      : _placeSorted(displayPages, placingItems, sortedPlacement);
  shownIds.addAll(placedItems.map(itemIdGetter));

  return (pages: displayPages, shownIds: shownIds);
}

/// [pages] with the edits that keep their rows in place applied, and the ids shown and moved. A move
/// changes a row's group, or its spot in [comparator]'s order.
({List<LoadedPage<T>> displayPages, Set<Object> shownIds, Set<Object> movedIds})
_applyEdits<T extends Object>(
  List<LoadedPage<T>> pages, {
  required Map<Object, ItemEdit<T>> edits,
  required ItemIdGetter<T> itemIdGetter,
  required GroupKeyOf<T, Object>? groupOf,
  required Comparator<T>? comparator,
}) {
  bool keepsPlace(T item, T editedItem) => comparator == null
      ? groupOf == null || groupOf(item) == groupOf(editedItem)
      : comparator(item, editedItem) == 0;
  final shownIds = <Object>{};
  final movedIds = <Object>{};

  // A loop, like the other per-item scans on the build path (APPENDIX.md#scan-loops).
  final displayPages = pages
      .map((page) {
        final displayPage = <T>[];
        for (final item in page.items) {
          final id = itemIdGetter(item);
          final edit = edits[id];
          if (edit == null || edit.stamp <= page.readStamp) {
            if (shownIds.add(id)) displayPage.add(item);
            continue;
          }

          final editedItem = edit.item;
          // A removal leaves its id free, so a fresher copy further down still shows.
          if (editedItem == null || shownIds.contains(id) || movedIds.contains(id)) continue;
          if (keepsPlace(item, editedItem)) {
            shownIds.add(id);
            displayPage.add(editedItem);
          } else {
            movedIds.add(id); // placed later, unless a later page shows the server's copy
          }
        }

        return LoadedPage(
          items: displayPage,
          readStamp: page.readStamp,
          previousSignal: page.previousSignal,
        );
      })
      .toList(growable: false);

  return (displayPages: displayPages, shownIds: shownIds, movedIds: movedIds);
}

/// Puts each of [items] where the order sorts it, and returns those placed. One sorting after every
/// loaded row waits for its page while more may follow.
List<T> _placeSorted<T extends Object>(
  List<LoadedPage<T>> displayPages,
  Iterable<T> items,
  SortedPlacement<T> sortedPlacement,
) {
  final comparator = sortedPlacement.comparator;
  final placedItems = <T>[];
  for (final item in items) {
    // Pages run in order, so its spot is in the 1st one that doesn't end before it.
    final page = displayPages.firstWhereOrNull(
      (page) => page.items.isNotEmpty && comparator(page.items.last, item) >= 0,
    );
    if (page != null) {
      page.items.insert(lowerBound(page.items, item, compare: comparator), item);
    } else if (sortedPlacement.mayHaveRowsAfter) {
      continue;
    } else {
      displayPages.last.items.add(item);
    }
    placedItems.add(item);
  }

  return placedItems;
}

/// Puts [items] where adding them one by one, oldest 1st, would: at the start of their group, newest
/// 1st, or on top when it isn't loaded. Returns them.
List<T> _placeAtGroupStarts<T extends Object>(
  List<LoadedPage<T>> displayPages,
  List<T> items,
  GroupKeyOf<T, Object>? groupOf,
) {
  if (groupOf == null) {
    displayPages.first.items.insertAll(0, items.reversed);

    return items;
  }

  final startByKey = _groupStarts(displayPages, items.map(groupOf).toSet(), groupOf);
  final itemsByStart = items.groupListsBy((item) => startByKey[groupOf(item)] ?? _opensOnTop);
  final openingGroups = (itemsByStart.remove(_opensOnTop) ?? []).groupListsBy(groupOf);
  // The last start 1st, so an insert can't shift the starts still to come.
  for (final MapEntry(key: start, value: joiners) in itemsByStart.entries.sorted(
    (a, b) => b.key.compareTo(a.key),
  )) {
    _insertAt(displayPages, start, joiners.reversed);
  }
  displayPages.first.items.insertAll(
    0,
    openingGroups.values.toList().reversed.expand((group) => group.reversed),
  );

  return items;
}

/// Where each of [keys] 1st shows in [displayPages], read as one list.
Map<Object, int> _groupStarts<T extends Object>(
  List<LoadedPage<T>> displayPages,
  Set<Object> keys,
  GroupKeyOf<T, Object> groupOf,
) {
  final startByKey = <Object, int>{};
  var flatIndex = 0;
  // A loop, like the other per-item scans on the build path (APPENDIX.md#scan-loops).
  for (final page in displayPages) {
    for (final item in page.items) {
      final key = groupOf(item);
      if (keys.contains(key)) startByKey[key] ??= flatIndex;
      if (startByKey.length == keys.length) return startByKey;
      flatIndex++;
    }
  }

  return startByKey;
}

/// Inserts [items] at [flatIndex] of [displayPages], read as one list.
void _insertAt<T extends Object>(
  List<LoadedPage<T>> displayPages,
  int flatIndex,
  Iterable<T> items,
) {
  var offset = flatIndex;
  for (final page in displayPages) {
    if (offset <= page.items.length) {
      page.items.insertAll(offset, items);

      return;
    }
    offset -= page.items.length;
  }
}

import 'package:collection/collection.dart';

import '/src/data/grouping/models/grouping.dart';
import '../typedefs/item_edit.dart';

/// The pages as they render, edits applied. An edit only covers a page read before it, since a page
/// read after already has the server's answer. [edits] runs oldest to newest.
List<List<T>> resolveDisplayPages<T extends Object>({
  required List<List<T>> pages,
  required List<int> readStamps,
  required Map<Object, ItemEdit<T>> edits,
  required Object Function(T item) itemId,
  required Grouping<T> grouping,
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
      final id = itemId(item);
      final edit = edits[id];
      if (edit == null || edit.stamp <= readStamp) {
        if (shownIds.add(id)) displayPage.add(item);
        continue;
      }

      final edited = edit.item;
      if (edited == null || !shownIds.add(id)) continue; // a fresher copy further down still shows
      if (grouping.isSameGroup(item, edited)) {
        displayPage.add(edited);
      } else {
        movedIds.add(id);
      }
    }
    displayPages.add(displayPage);
  }
  if (displayPages.isEmpty) return displayPages;

  // A new item shows while some page predates it. Once none does, the server's answer is in.
  final oldestRead = readStamps.min;
  bool isNew(Object id, ItemEdit<T> edit) =>
      acceptsNewItems && !shownIds.contains(id) && edit.stamp > oldestRead;
  final toPlace = edits.entries
      .where((entry) => movedIds.contains(entry.key) || isNew(entry.key, entry.value))
      .map((entry) => entry.value.item)
      .nonNulls; // a removal has nothing to place
  for (final item in toPlace) {
    _place(displayPages, item, grouping);
  }

  return displayPages;
}

/// Turns [Grouping.placementOf]'s flat index into a page and an offset.
void _place<T extends Object>(List<List<T>> pages, T item, Grouping<T> grouping) {
  var index = grouping.placementOf(item, flatItems: () => pages.flattened.toList(growable: false));
  for (final page in pages) {
    if (index <= page.length) {
      page.insert(index, item);

      return;
    }
    index -= page.length;
  }
}

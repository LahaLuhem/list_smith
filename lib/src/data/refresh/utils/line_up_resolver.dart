import 'dart:collection';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '/src/data/edits/models/removal_stamps.dart';
import '/src/data/pagination/typedefs/item_id_getter.dart';

/// Enough pages to hold the rows that moved up into the removed rows' places.
@internal
int rereadPageCount(int removedCount, {required int pageSize, required int maxCount}) =>
    math.min((removedCount / pageSize).ceil(), maxCount);

/// The pages a depth reload reads again before it commits, enough before each boundary to hold the rows
/// a removal could have pulled past it.
@internal
SplayTreeSet<int> resolveRereadIndexes<T extends Object>({
  required Iterable<List<T>> oldPages,
  required List<List<T>> freshPages,
  required Map<int, int> readStamps,
  required RemovalStamps removalStamps,
  required ItemIdGetter<T> itemIdGetter,
  required int pageSize,
}) {
  final removedIds = removalStamps.after(readStamps.values.min);
  // The 1st page each removed row sat in, old or fresh, so it counts above every boundary after. A new
  // item on no page counts above them all.
  late final removedPageIndexById = oldPages.indexed
      .followedBy(freshPages.indexed)
      .expand((indexed) => indexed.$2.map((item) => (id: itemIdGetter(item), index: indexed.$1)))
      .where((row) => removedIds.contains(row.id))
      .groupFoldBy<Object, int>(
        (row) => row.id,
        (index, row) => math.min(index ?? row.index, row.index),
      );

  return SplayTreeSet.of(
    Iterable.generate(freshPages.length - 1, (offset) => offset + 1).expand((boundaryIndex) {
      // Booked any time after the page before went out, since the server may have had it sooner.
      final crossedCount = removalStamps
          .after(readStamps[boundaryIndex - 1]!)
          .where((id) => (removedPageIndexById[id] ?? 0) < boundaryIndex)
          .length;
      final count = rereadPageCount(crossedCount, pageSize: pageSize, maxCount: boundaryIndex);

      return Iterable.generate(count, (offset) => boundaryIndex - count + offset);
    }),
  );
}

/// [freshPages] with the rows they lack from [rereadItemsByIndex], each in front of the page after the
/// fresh row it follows in its read.
@internal
List<List<T>> resolveLinedUpPages<T extends Object>({
  required List<List<T>> freshPages,
  required Map<int, List<T>> rereadItemsByIndex,
  required ItemIdGetter<T> itemIdGetter,
}) {
  final freshPageIndexById = freshPages.indexed
      .expand((indexed) => indexed.$2.map((item) => (id: itemIdGetter(item), index: indexed.$1)))
      .groupFoldBy<Object, int>((row) => row.id, (index, row) => index ?? row.index);
  bool isFresh(T item) => freshPageIndexById.containsKey(itemIdGetter(item));
  final slidRowsByPageIndex = rereadItemsByIndex.keys
      .splitBetween((index, nextIndex) => nextIndex != index + 1)
      .expand(
        (run) =>
            run.expand((index) => rereadItemsByIndex[index]!).splitBefore(isFresh).expand((piece) {
              // A piece opens on the fresh row its rows follow, or opens the run.
              final followedPageIndex = freshPageIndexById[itemIdGetter(piece.first)];
              final pageIndex = followedPageIndex == null ? run.first : followedPageIndex + 1;

              return piece.whereNot(isFresh).map((item) => (pageIndex: pageIndex, item: item));
            }),
      )
      .where((slidRow) => slidRow.pageIndex < freshPages.length)
      // Once, where it's 1st read.
      .groupFoldBy<Object, ({int pageIndex, T item})>(
        (slidRow) => itemIdGetter(slidRow.item),
        (firstSlidRow, slidRow) => firstSlidRow ?? slidRow,
      )
      .values
      .groupListsBy((slidRow) => slidRow.pageIndex);

  return freshPages
      .mapIndexed(
        (index, items) => [
          ...?slidRowsByPageIndex[index]?.map((slidRow) => slidRow.item),
          ...items,
        ],
      )
      .toList(growable: false);
}

import 'package:collection/collection.dart';

/// Reorders [items] so items sharing a group key (per [keyOf]) are contiguous, in the order each group
/// first appears, keeping the order of items within a group.
///
/// This is the sync path's ordering step: a sync list holds all its items, so it can regroup them and
/// the consumer need not pre-sort. The async path never calls this (it cannot reorder across pages).
/// Kept widget-free and pure so it is unit-tested directly, mirroring `resolveSyncSearch` and the
/// policy resolvers. Relies on `groupListsBy` keeping groups in first-insertion order.
List<T> bucketByGroup<T extends Object>(Iterable<T> items, Object Function(T item) keyOf) =>
    items.groupListsBy(keyOf).values.flattened.toList(growable: false);

/// Whether [current] begins a new group: true for the first item (a null [previous]), or when
/// [current]'s group key differs from [previous]'s (per [keyOf], compared with `==`).
///
/// The per-item decision both render paths share to place a header above a group's first item. It
/// assumes items are already contiguous by group, which [bucketByGroup] guarantees on the sync path
/// and the consumer's fetcher must guarantee on the async path.
bool isGroupStart<T extends Object>(T? previous, T current, Object Function(T item) keyOf) =>
    previous == null || keyOf(previous) != keyOf(current);

/// Whether every group in [items] is contiguous: each group key (per [keyOf], compared with `==`)
/// occupies a single run, never recurring once a different key has intervened.
///
/// A debug-time check for the async path, which cannot reorder items across pages and so relies on
/// the fetcher returning them already grouped by key. The sync path never needs it: [bucketByGroup]
/// makes contiguity hold by construction. Splits the keys into runs at each change, then checks each
/// run opens a key not seen in an earlier run.
bool groupsAreContiguous<T extends Object>(Iterable<T> items, Object Function(T item) keyOf) {
  final runKeys = items
      .map(keyOf)
      .splitBetween((first, second) => first != second)
      .map((run) => run.first);

  return runKeys.toList(growable: false).length == runKeys.toSet().length;
}

import 'package:collection/collection.dart';

import '../models/group_order_policy.dart';

/// Reorders [items] so ones sharing a group key sit together, groups in first-appearance order, item
/// order kept inside a group.
///
/// The sync path's ordering step. Async never calls it. Leans on `groupListsBy` keeping groups in first-insertion
/// order.
List<T> bucketByGroup<T extends Object>(Iterable<T> items, Object Function(T item) keyOf) =>
    items.groupListsBy(keyOf).values.flattened.toList(growable: false);

/// One flag per item: whether it draws its group's header.
///
/// [policy] gets first look and can reject out-of-order items. Walks [items] once, twice while the order
/// is being checked.
BoolList resolveHeaderFlags<T extends Object>(
  Iterable<T> items,
  Object Function(T item) keyOf,
  GroupOrderPolicy policy,
) {
  switch (policy) {
    case RepairHeadersPolicy():
      assert(
        groupsAreContiguous(items, keyOf),
        'Grouping on an async list needs each page ordered by group key. A group key came back '
        'after its section ended, so its later items will render without a header.',
      );
    case FailOnUnorderedPolicy():
      if (!groupsAreContiguous(items, keyOf)) {
        throw StateError(
          'Grouping on an async list needs each page ordered by group key. A group key came back '
          'after its section ended, and FailOnUnorderedPolicy turns that into this error.',
        );
      }
  }

  return headerFlagsByFirstSighting(items, keyOf);
}

/// True the 1st time a key shows up, false after, so a split group never draws 2 headers.
///
/// A loop on purpose: this runs per item on every build, and the chain version measured several times
/// slower (`APPENDIX.md#scan-loops`). Packed, since the item builder reads it per row.
BoolList headerFlagsByFirstSighting<T extends Object>(
  Iterable<T> items,
  Object Function(T item) keyOf,
) {
  final seenKeys = <Object>{};
  final headerFlags = BoolList.empty();
  Object? runKey;
  for (final item in items) {
    final key = keyOf(item);
    headerFlags.add(key != runKey && seenKeys.add(key)); // only a run's first item can open a group
    runKey = key;
  }

  return headerFlags;
}

/// Whether every group key in [items] sits in one unbroken run, never coming back after a different
/// key has shown up.
///
/// The async path's order check. Sync never needs one, [bucketByGroup] already guarantees it. A loop
/// for the same reason as [headerFlagsByFirstSighting], and it bails at the 1st repeat.
bool groupsAreContiguous<T extends Object>(Iterable<T> items, Object Function(T item) keyOf) {
  final seenKeys = <Object>{};
  Object? runKey;
  for (final item in items) {
    final key = keyOf(item);
    if (key != runKey && !seenKeys.add(key)) return false;
    runKey = key;
  }

  return true;
}

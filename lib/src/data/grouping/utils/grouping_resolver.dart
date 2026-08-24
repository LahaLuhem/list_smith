import 'package:collection/collection.dart';

import '../models/group_order_policy.dart';

/// Reorders [items] so items sharing a group key (per [keyOf]) are contiguous, in the order each group
/// first appears, keeping the order of items within a group.
///
/// This is the sync path's ordering step: a sync list holds all its items, so it can regroup them and
/// the consumer need not pre-sort. The async path never calls this (it cannot reorder across pages).
/// Kept widget-free and pure so it is unit-tested directly, mirroring `resolveSyncSearch` and the
/// policy resolvers. Relies on `groupListsBy` keeping groups in first-insertion order.
List<T> bucketByGroup<T extends Object>(Iterable<T> items, Object Function(T item) keyOf) =>
    items.groupListsBy(keyOf).values.flattened.toList(growable: false);

/// One flag per item: whether it draws its group's header.
///
/// [policy] gets first look and can reject out-of-order items. Whatever it lets through goes to
/// [headerFlagsByFirstSighting].
List<bool> resolveHeaderFlags<T extends Object>(
  List<T> items,
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

/// True the first time a key shows up, false after, so a split group never draws two headers.
///
/// Split out because the default policy asserts before reaching it, so a debug test can only get
/// here by calling directly. Checks `seen` only where the key changes, since items mid-run cannot
/// open a group.
List<bool> headerFlagsByFirstSighting<T extends Object>(
  List<T> items,
  Object Function(T item) keyOf,
) {
  final seen = <Object>{};
  Object? runKey;

  return List<bool>.generate(items.length, (index) {
    final key = keyOf(items[index]);
    if (key == runKey) return false;
    runKey = key;

    return seen.add(key);
  }, growable: false);
}

/// Whether every group in [items] is contiguous: each group key (per [keyOf], compared with `==`)
/// occupies a single run, never recurring once a different key has intervened.
///
/// The order check for the async path, which cannot reorder items across pages and so relies on
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

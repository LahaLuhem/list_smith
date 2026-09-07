import 'package:collection/collection.dart';

import '../models/group_order_policy.dart';

/// Reorders [items] so items sharing a group key (per [keyOf]) sit contiguously, groups in
/// first-appearance order, item order kept within a group.
///
/// The sync path's ordering step, so the consumer needn't pre-sort. Async never calls it. Leans on
/// `groupListsBy` keeping groups in first-insertion order.
List<T> bucketByGroup<T extends Object>(Iterable<T> items, Object Function(T item) keyOf) =>
    items.groupListsBy(keyOf).values.flattened.toList(growable: false);

/// One flag per item: whether it draws its group's header.
///
/// [policy] gets first look and can reject out-of-order items. Whatever it lets through goes to
/// [headerFlagsByFirstSighting]. Walks [items] once, twice while the order is being checked.
List<bool> resolveHeaderFlags<T extends Object>(
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

/// True the first time a key shows up, false after, so a split group never draws two headers.
///
/// Split out because the default policy asserts before reaching it, so a debug test only gets here
/// by calling directly. Only a run's first item can open a group, so `seenKeys` is asked once per run.
/// A list, because the item builder indexes into it.
List<bool> headerFlagsByFirstSighting<T extends Object>(
  Iterable<T> items,
  Object Function(T item) keyOf,
) {
  final seenKeys = <Object>{};

  return items
      .map(keyOf)
      .splitBetween((first, second) => first != second)
      .expand((run) => run.mapIndexed((index, key) => index == 0 && seenKeys.add(key)))
      .toList(growable: false);
}

/// Whether every group in [items] is contiguous: each group key (per [keyOf], compared with `==`)
/// occupies a single run, never recurring once a different key has intervened.
///
/// The async path's order check, since it leans on the fetcher grouping for it. Sync never needs
/// one, [bucketByGroup] makes contiguity hold by construction. Splits the keys into runs at each
/// change, then checks each run opens a key no earlier run used, stopping at the first repeat.
bool groupsAreContiguous<T extends Object>(Iterable<T> items, Object Function(T item) keyOf) {
  final seenKeys = <Object>{};

  return items
      .map(keyOf)
      .splitBetween((first, second) => first != second)
      .map((run) => run.first)
      .every(seenKeys.add);
}

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '/src/data/presentation/typedefs/group_header.dart';
import '../models/group_order_policy.dart';
import '../typedefs/group_key_of.dart';

/// Reorders [items] so ones sharing a group key sit together, groups in first-appearance order, item
/// order kept inside a group.
///
/// The sync path's ordering step. Async never calls it. Leans on `groupListsBy` keeping groups in first-insertion
/// order.
@internal
List<T> bucketByGroup<T extends Object>(Iterable<T> items, GroupKeyOf<T, Object> keyOf) =>
    items.groupListsBy(keyOf).values.flattened.toList(growable: false);

/// One flag per item: whether it draws its group's header.
///
/// [policy] gets first look and can reject out-of-order items. Walks [items] once, twice while the order
/// is being checked.
@internal
BoolList resolveHeaderFlags<T extends Object>(
  Iterable<T> items,
  GroupKeyOf<T, Object> keyOf,
  GroupOrderPolicy policy,
) {
  _checkOrder(items, keyOf, policy);

  return headerFlagsByFirstSighting(items, keyOf);
}

/// Each group's header for one build: by its 1st item, or its last on a reversed list. [policy] can
/// reject out-of-order items.
@internal
List<GroupHeader> resolveGroupHeaders<T extends Object>(
  Iterable<T> items,
  GroupKeyOf<T, Object> keyOf,
  GroupOrderPolicy policy, {
  required bool isReversed,
}) {
  _checkOrder(items, keyOf, policy);

  return groupHeadersByFirstRun(items, keyOf, isReversed: isReversed);
}

/// One header per key, on the key's 1st run, so a split group never draws 2.
///
/// A loop for the same reason as [headerFlagsByFirstSighting].
@visibleForTesting
List<GroupHeader> groupHeadersByFirstRun<T extends Object>(
  Iterable<T> items,
  GroupKeyOf<T, Object> keyOf, {
  required bool isReversed,
}) {
  final seenKeys = <Object>{};
  final headers = <GroupHeader>[];
  Object? runKey;
  Object? firstRunKey; // the run's key while this is that key's 1st run
  var index = 0;
  for (final item in items) {
    final key = keyOf(item);
    if (key != runKey) {
      if (isReversed && firstRunKey != null) headers.add((itemIndex: index - 1, key: firstRunKey));
      runKey = key;
      firstRunKey = seenKeys.add(key) ? key : null;
      if (!isReversed && firstRunKey != null) headers.add((itemIndex: index, key: firstRunKey));
    }
    index++;
  }
  if (isReversed && firstRunKey != null) headers.add((itemIndex: index - 1, key: firstRunKey));

  return headers;
}

void _checkOrder<T extends Object>(
  Iterable<T> items,
  GroupKeyOf<T, Object> keyOf,
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
}

/// True the 1st time a key shows up, false after, so a split group never draws 2 headers.
///
/// A loop on purpose: this runs per item on every build, and the chain version measured several times
/// slower (`APPENDIX.md#scan-loops`). Packed, since the item builder reads it per row.
@internal
BoolList headerFlagsByFirstSighting<T extends Object>(
  Iterable<T> items,
  GroupKeyOf<T, Object> keyOf,
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
@visibleForTesting
bool groupsAreContiguous<T extends Object>(Iterable<T> items, GroupKeyOf<T, Object> keyOf) {
  final seenKeys = <Object>{};
  Object? runKey;
  for (final item in items) {
    final key = keyOf(item);
    if (key != runKey && !seenKeys.add(key)) return false;
    runKey = key;
  }

  return true;
}

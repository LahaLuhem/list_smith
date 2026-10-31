import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '/src/data/presentation/typedefs/group_header.dart';
import '../models/group_order_policy.dart';
import '../typedefs/group_key_of.dart';

/// Reorders [items] so ones sharing a group key sit together, groups in first-appearance order, item
/// order kept inside a group.
///
/// Sync orders with it on every query, async only once a key comes back. Leans on `groupListsBy`
/// keeping groups in first-insertion order.
@internal
List<T> bucketByGroup<T extends Object>(Iterable<T> items, GroupKeyOf<T, Object> keyOf) =>
    items.groupListsBy(keyOf).values.flattened.toList(growable: false);

/// Each group's header for one build: by its 1st item, or its last on a reversed list.
///
/// When a key comes back after its run, [policy] either gathers [pagedItems] into `gatheredItems` or
/// throws. It stays null for grouped items, so they're never copied.
@internal
({List<GroupHeader> headers, List<T>? gatheredItems}) resolveGroupHeaders<T extends Object>(
  List<List<T>> pagedItems,
  GroupKeyOf<T, Object> keyOf,
  GroupOrderPolicy policy, {
  required bool isReversed,
}) {
  final headers = groupHeadersIfContiguous(pagedItems, keyOf, isReversed: isReversed);
  if (headers != null) return (headers: headers, gatheredItems: null);

  switch (policy) {
    case RepairHeadersPolicy():
      final gatheredItems = bucketByGroup(pagedItems.flattened, keyOf);

      return (
        // Gathered, so no key comes back.
        headers: groupHeadersIfContiguous([gatheredItems], keyOf, isReversed: isReversed)!,
        gatheredItems: gatheredItems,
      );
    case FailOnUnorderedPolicy():
      throw StateError(
        'Grouping on an async list needs each page ordered by group key. A group key came back '
        'after its section ended, and FailOnUnorderedPolicy turns that into this error.',
      );
  }
}

/// A header at each group's run, or null once a key comes back after its run.
///
/// Loops over the pages, not a flatten of them, since it runs per item on every build (`APPENDIX.md#scan-loops`).
/// It doubles as the order check, so grouped items need no 2nd pass.
@visibleForTesting
List<GroupHeader>? groupHeadersIfContiguous<T extends Object>(
  List<List<T>> pagedItems,
  GroupKeyOf<T, Object> keyOf, {
  required bool isReversed,
}) {
  final seenKeys = <Object>{};
  final headers = <GroupHeader>[];
  Object? runKey;
  var index = 0;
  for (final items in pagedItems) {
    for (final item in items) {
      final key = keyOf(item);
      if (key != runKey) {
        if (!seenKeys.add(key)) return null;
        if (isReversed && runKey != null) headers.add((itemIndex: index - 1, key: runKey));
        if (!isReversed) headers.add((itemIndex: index, key: key));
        runKey = key;
      }
      index++;
    }
  }
  if (isReversed && runKey != null) headers.add((itemIndex: index - 1, key: runKey));

  return headers;
}

part of '../grouping.dart';

/// Grouping by a key pulled off each item, one header per group. Built via [Grouping.by].
///
/// The key is erased to `Object`. The private constructor is what keeps that safe: every key reaching
/// [headerFor] came from this instance's own [groupOf].
@internal
final class const KeyedGrouping<T extends Object>._({
  /// Pulls an item's group key.
  @override @internal required final GroupKeyOf<T, Object> groupOf,

  /// Builds a group's header from its key.
  required final GroupHeaderBuilder<Object> headerFor,

  /// What to do when async pages don't arrive grouped by key.
  required final GroupOrderPolicy orderPolicy,
}) extends Grouping<T> {
  @override
  @internal
  List<T> arrange(Iterable<T> items) => bucketByGroup(items, groupOf);

  @override
  @internal
  ({List<List<T>> pagedItems, GroupHeaders groupHeaders}) sectionsOver(List<List<T>> pagedItems) {
    final (:headers, :gatheredItems) = resolveGroupHeaders(pagedItems, groupOf, orderPolicy);

    return (
      pagedItems: gatheredItems == null ? pagedItems : [gatheredItems],
      groupHeaders: GroupHeaders(headers: headers, headerFor: headerFor),
    );
  }

  @override
  String toString() => 'KeyedGrouping(orderPolicy: $orderPolicy)';
}

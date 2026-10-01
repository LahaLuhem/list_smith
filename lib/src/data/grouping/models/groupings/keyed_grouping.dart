part of '../grouping.dart';

/// Grouping by a key pulled off each item, one header per group. Built via [Grouping.by].
///
/// The key is erased to `Object`. The private constructor is what keeps that safe: every key reaching
/// [headerFor] came from this instance's own [groupOf].
final class const KeyedGrouping<T extends Object>._({
  /// Pulls an item's group key.
  @override required final GroupKeyOf<T, Object> groupOf,

  /// Builds a group's header from its key.
  required final GroupHeaderBuilder<Object> headerFor,

  /// What to do when async pages don't arrive grouped by key.
  required final GroupOrderPolicy orderPolicy,
}) extends Grouping<T> {
  @override
  List<T> arrange(Iterable<T> items) => bucketByGroup(items, groupOf);

  @override
  ItemBuilder<T> decorate(
    ItemBuilder<T> itemBuilder, {
    required Iterable<T> Function() flattenItems,
    required Axis axis,
  }) {
    final headerFlags = resolveHeaderFlags(flattenItems(), groupOf, orderPolicy);

    return (_, item, index) => GroupedItem<T>(
      itemBuilder: itemBuilder,
      groupOf: groupOf,
      headerFor: headerFor,
      scrollDirection: axis,
      drawsHeader: headerFlags[index],
      item: item,
      index: index,
    );
  }

  @override
  String toString() => 'KeyedGrouping(orderPolicy: $orderPolicy)';
}

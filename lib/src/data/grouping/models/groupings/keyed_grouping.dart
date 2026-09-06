part of '../grouping.dart';

/// Grouping by a key extracted from each item, with one header per group. Built via [Grouping.by].
///
/// Key extractor and header builder, with the key erased to `Object`. The private constructor keeps
/// that erasure sound: every key reaching [headerFor] came from this instance's own [groupOf].
final class KeyedGrouping<T extends Object> extends Grouping<T> {
  /// Extracts an item's group key, erased to `Object`.
  final Object Function(T item) groupOf;

  /// Builds a group's header from its key, erased to `Object`.
  final Widget Function(BuildContext context, Object key) headerFor;

  /// What to do when async pages do not arrive grouped by key.
  final GroupOrderPolicy orderPolicy;

  const new _({required this.groupOf, required this.headerFor, required this.orderPolicy});

  @override
  List<T> arrange(Iterable<T> items) => bucketByGroup(items, groupOf);

  @override
  ItemBuilder<T> decorate(
    ItemBuilder<T> itemBuilder, {
    required List<T> Function() flatItems,
    required Axis axis,
  }) {
    final headerFlags = resolveHeaderFlags(flatItems(), groupOf, orderPolicy);

    return (_, item, index) => GroupedItem<T>(
      itemBuilder: itemBuilder,
      groupOf: groupOf,
      headerFor: headerFor,
      scrollDirection: axis,
      showHeader: headerFlags[index],
      item: item,
      index: index,
    );
  }

  @override
  String toString() => 'KeyedGrouping(orderPolicy: $orderPolicy)';
}

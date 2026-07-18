part of '../grouping.dart';

/// Grouping by a key extracted from each item, with one header per group. Built via [Grouping.by].
///
/// Holds the key extractor and header builder with the key type erased to `Object` (see [Grouping.by]
/// for why the key is erased). The constructor is private so an instance can only come from
/// [Grouping.by]: that keeps the erasure sound, since every key passed to [headerFor] was produced by
/// this instance's own [groupOf].
final class KeyedGrouping<T extends Object> extends Grouping<T> {
  /// Extracts an item's group key, erased to `Object`.
  final Object Function(T item) groupOf;

  /// Builds a group's header from its key, erased to `Object`.
  final Widget Function(BuildContext context, Object key) headerFor;

  const KeyedGrouping._({required this.groupOf, required this.headerFor});

  @override
  List<T> arrange(Iterable<T> items) => bucketByGroup(items, groupOf);

  @override
  ItemBuilder<T> decorate(
    ItemBuilder<T> itemBuilder, {
    required List<T> Function() flatItems,
    required Axis axis,
  }) {
    final items = flatItems();
    assert(
      groupsAreContiguous(items, groupOf),
      'Grouping on an async list needs each page ordered by group key; a group key reappeared '
      'after its section ended, so its header would fragment.',
    );

    return (_, item, index) => GroupedItem<T>(
      itemBuilder: itemBuilder,
      groupOf: groupOf,
      headerFor: headerFor,
      scrollDirection: axis,
      previous: index == 0 ? null : items[index - 1],
      item: item,
      index: index,
    );
  }

  @override
  String toString() => 'KeyedGrouping()';
}

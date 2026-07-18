import 'package:flutter/widgets.dart';

import '/src/data/grouping/models/grouping.dart';
import '/src/data/grouping/utils/grouping_resolver.dart';
import '/src/data/presentation/typedefs/item_builder.dart';

/// Renders one list item, prefixed with its group's header when the item begins a new group.
///
/// Shared by both render paths so header placement lives in one spot. Built only where grouping is
/// active, and only where a header is wanted: a group's header is stacked before its first item along
/// the list's [scrollDirection] (above it, for a vertical list). [previous] is the item before [item]
/// in display order, or null at the start, and drives the [isGroupStart] check. Takes the group-key
/// extractor ([groupOf]) and header builder ([headerFor]) directly, rather than a whole `Grouping`, so
/// this presentation widget stays independent of the grouping model.
class GroupedItem<T extends Object> extends StatelessWidget {
  /// Builds the item itself; the header is prefixed around its widget.
  final ItemBuilder<T> itemBuilder;

  /// Extracts an item's group key (erased to `Object`), for the [isGroupStart] look-back.
  final Object Function(T item) groupOf;

  /// Builds a group's header from its key (erased to `Object`).
  final Widget Function(BuildContext context, Object key) headerFor;

  /// The list's scroll axis, so the header stacks before the item along it.
  final Axis scrollDirection;

  /// The item before [item] in display order, or null at the start of the list.
  final T? previous;

  /// The item to render.
  final T item;

  /// The item's index in the flattened list, passed through to [itemBuilder].
  final int index;

  /// Creates a grouped item cell.
  const GroupedItem({
    required this.itemBuilder,
    required this.groupOf,
    required this.headerFor,
    required this.scrollDirection,
    required this.previous,
    required this.item,
    required this.index,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final itemWidget = itemBuilder(context, item, index);
    if (!isGroupStart(previous, item, groupOf)) return itemWidget;

    return Flex(
      direction: scrollDirection,
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      children: [headerFor(context, groupOf(item)), itemWidget],
    );
  }
}

/// Wraps [itemBuilder] so each group's first item is prefixed with its header, or returns it unchanged
/// when [grouping] is not a [KeyedGrouping].
///
/// The single place [GroupedItem] is built, shared by both render paths. [items] is the flattened list
/// in display order; each cell looks one item back through it to decide whether it starts a group.
ItemBuilder<T> groupedItemBuilder<T extends Object>(
  Grouping<T> grouping,
  ItemBuilder<T> itemBuilder,
  Axis scrollDirection,
  List<T> items,
) => grouping is! KeyedGrouping<T>
    ? itemBuilder
    : (_, item, index) => GroupedItem<T>(
        itemBuilder: itemBuilder,
        groupOf: grouping.groupOf,
        headerFor: grouping.headerFor,
        scrollDirection: scrollDirection,
        previous: index == 0 ? null : items[index - 1],
        item: item,
        index: index,
      );

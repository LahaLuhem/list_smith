import 'package:flutter/widgets.dart';

import '/src/data/presentation/typedefs/item_builder.dart';

/// Renders one list item, prefixed with its group's header when the item begins a new group.
///
/// Shared by both render paths, so header placement lives in one spot. The header stacks before the
/// group's first item along [scrollDirection], with `resolveHeaderFlags` deciding up front which
/// item that is. Takes [groupOf] and [headerFor] directly rather than a whole `Grouping`, so this
/// widget stays independent of the grouping model.
class GroupedItem<T extends Object> extends StatelessWidget {
  /// Builds the item itself, with the header prefixed around its widget.
  final ItemBuilder<T> itemBuilder;

  /// Extracts an item's group key (erased to `Object`), to label the header.
  final Object Function(T item) groupOf;

  /// Builds a group's header from its key (erased to `Object`).
  final Widget Function(BuildContext context, Object key) headerFor;

  /// The list's scroll axis, so the header stacks before the item along it.
  final Axis scrollDirection;

  /// Whether this item opens its group, so it draws the header.
  final bool drawsHeader;

  /// The item to render.
  final T item;

  /// The item's index in the flattened list, passed through to [itemBuilder].
  final int index;

  /// Creates a grouped item cell.
  const new({
    required this.itemBuilder,
    required this.groupOf,
    required this.headerFor,
    required this.scrollDirection,
    required this.drawsHeader,
    required this.item,
    required this.index,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final itemWidget = itemBuilder(context, item, index);
    if (!drawsHeader) return itemWidget;

    return Flex(
      direction: scrollDirection,
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      children: [headerFor(context, groupOf(item)), itemWidget],
    );
  }
}

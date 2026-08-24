import 'package:flutter/widgets.dart';

import '/src/data/presentation/typedefs/item_builder.dart';

/// Renders one list item, prefixed with its group's header when the item begins a new group.
///
/// Shared by both render paths so header placement lives in one spot. Built only where grouping is
/// active: a group's header is stacked before its first item along the list's [scrollDirection]
/// (above it, for a vertical list). `resolveHeaderFlags` decides that up front and passes it in as
/// [showHeader]. Takes the group-key extractor ([groupOf]) and header builder ([headerFor])
/// directly, rather than a whole `Grouping`, so this presentation widget stays independent of the
/// grouping model.
class GroupedItem<T extends Object> extends StatelessWidget {
  /// Builds the item itself; the header is prefixed around its widget.
  final ItemBuilder<T> itemBuilder;

  /// Extracts an item's group key (erased to `Object`), to label the header.
  final Object Function(T item) groupOf;

  /// Builds a group's header from its key (erased to `Object`).
  final Widget Function(BuildContext context, Object key) headerFor;

  /// The list's scroll axis, so the header stacks before the item along it.
  final Axis scrollDirection;

  /// Whether this item opens its group, so it draws the header.
  final bool showHeader;

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
    required this.showHeader,
    required this.item,
    required this.index,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final itemWidget = itemBuilder(context, item, index);
    if (!showHeader) return itemWidget;

    return Flex(
      direction: scrollDirection,
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      children: [headerFor(context, groupOf(item)), itemWidget],
    );
  }
}

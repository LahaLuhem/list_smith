import 'package:flutter/widgets.dart';

import '/src/data/grouping/typedefs/group_header_builder.dart';
import '/src/data/grouping/typedefs/group_key_of.dart';
import '/src/data/presentation/typedefs/item_builder.dart';

/// Renders one list item, with its group's header on top when the item opens a new group.
///
/// Shared by both render paths, so header placement lives in one spot. Takes [groupOf] and [headerFor]
/// directly rather than a whole `Grouping`, so it stays independent of the grouping model.
class const GroupedItem<T extends Object>({
  /// Builds the item itself.
  required final ItemBuilder<T> itemBuilder,

  /// Pulls an item's group key, to label the header.
  required final GroupKeyOf<T, Object> groupOf,

  /// Builds a group's header from its key.
  required final GroupHeaderBuilder<Object> headerFor,

  /// The scroll axis, so the header stacks before the item along it.
  required final Axis scrollDirection,

  /// Whether this item opens its group, and so draws the header.
  required final bool drawsHeader,

  /// The item to render.
  required final T item,

  /// Index into the flattened list, passed through to [itemBuilder].
  required final int index,
  super.key,
}) extends StatelessWidget {
  /// Creates it.
  this;

  @override
  Widget build(BuildContext context) => Flex(
    direction: scrollDirection,
    mainAxisSize: .min,
    crossAxisAlignment: .stretch,
    // Keyed slots in one shape, so the item keeps its state as the header comes and goes.
    children: [
      if (drawsHeader) KeyedSubtree(key: _headerSlot, child: headerFor(context, groupOf(item))),
      KeyedSubtree(key: _itemSlot, child: itemBuilder(context, item, index)),
    ],
  );

  static const _headerSlot = ValueKey('header');
  static const _itemSlot = ValueKey('item');
}

/// @docImport '/src/widgets/list_smith.dart';
library;

import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import '/src/data/presentation/typedefs/item_builder.dart';
import '/src/widgets/grouped_item.dart';
import '../typedefs/group_header_builder.dart';
import '../typedefs/group_key_of.dart';
import '../utils/grouping_resolver.dart';
import 'group_order_policy.dart';

part 'groupings/keyed_grouping.dart';
part 'groupings/no_grouping.dart';

/// How a list_smith list splits its items into labelled sections.
///
/// [NoGrouping] (the default) is a flat list with no headers. [Grouping.by] turns sections on. Both
/// [ListSmith] constructors take one, and they differ only in how they order items.
sealed class Grouping<T extends Object> {
  /// Const base constructor.
  const new();

  /// Orders [items] into their display sequence. Once per resolve, sync path only, since async
  /// can't reorder across pages. [NoGrouping] hands them back as-is, [KeyedGrouping] buckets them.
  @internal
  List<T> arrange(Iterable<T> items);

  /// Wraps [itemBuilder] into the per-item builder for one build. Once per build, not per item.
  ///
  /// [KeyedGrouping] prefixes each group's first item with its header along [axis], reading
  /// [flatItems] once for the look-back. [NoGrouping] hands [itemBuilder] straight back and never
  /// calls [flatItems], which is why that is a callback: the ungrouped path skips the flatten.
  @internal
  ItemBuilder<T> decorate(
    ItemBuilder<T> itemBuilder, {
    required List<T> Function() flatItems,
    required Axis axis,
  });

  /// Groups items by the key from [groupBy], drawing each section's header with [headerBuilder].
  ///
  /// The header sits above each group's first item. [K] is inferred from [groupBy] and stays typed
  /// in [headerBuilder], erased to `Object` inside so [ListSmith] needs no second type parameter.
  /// Type [groupBy]'s parameter, or pass a typed function, so `K` infers instead of widening to
  /// `Object`.
  ///
  /// The two paths order differently. Sync holds every item, so it buckets the filtered ones into
  /// contiguous runs (groups in first-appearance order, item order kept) and your input can arrive
  /// any way round. Async can't reorder across pages, so the fetcher must return items already
  /// grouped by key, with [orderPolicy] deciding what happens when it doesn't. Either way a group
  /// spanning a page boundary gets one header.
  static Grouping<T> by<T extends Object, K extends Object>({
    required GroupKeyOf<T, K> groupBy,
    required GroupHeaderBuilder<K> headerBuilder,
    GroupOrderPolicy orderPolicy = const RepairHeadersPolicy(),
  }) => KeyedGrouping<T>._(
    groupOf: groupBy,
    headerFor: (context, key) => headerBuilder(context, key as K),
    orderPolicy: orderPolicy,
  );
}

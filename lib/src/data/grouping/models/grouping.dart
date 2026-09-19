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

/// How a list splits its items into labelled sections.
///
/// [NoGrouping] (the default) is flat, no headers. [Grouping.by] turns sections on. Both [ListSmith]
/// constructors take one.
sealed class Grouping<T extends Object> {
  /// Const base constructor.
  const new();

  /// Orders [items] for display. Sync path only, since async can't reorder across pages.
  @internal
  List<T> arrange(Iterable<T> items);

  /// Wraps [itemBuilder] into the builder for one build. Once per build, not per item.
  ///
  /// [flatItems] is a callback because the ungrouped path never flattens and shouldn't pay for it.
  @internal
  ItemBuilder<T> decorate(
    ItemBuilder<T> itemBuilder, {
    required Iterable<T> Function() flatItems,
    required Axis axis,
  });

  /// Groups items by the key from [groupBy], drawing each section's header with [headerBuilder].
  ///
  /// Type [groupBy]'s parameter, or pass an already-typed function, so `K` infers instead of widening
  /// to `Object`.
  ///
  /// Sync reorders for you, so your input can arrive any way round. Async can't reorder across pages,
  /// so the fetcher has to return items already grouped, and [orderPolicy] says what happens when it
  /// doesn't. Either way a group split over a page boundary gets one header.
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

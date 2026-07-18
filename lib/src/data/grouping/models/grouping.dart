/// @docImport '/src/widgets/list_smith.dart';
library;

import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import '/src/data/presentation/typedefs/item_builder.dart';
import '/src/widgets/grouped_item.dart';
import '../typedefs/group_header_builder.dart';
import '../typedefs/group_key_of.dart';
import '../utils/grouping_resolver.dart';

part 'groupings/keyed_grouping.dart';
part 'groupings/no_grouping.dart';

/// How a list_smith list splits its items into labelled sections.
///
/// A sealed, injected, defaulted seam, like the pagination end and search cache policies: the default
/// is [NoGrouping] (a flat list, no headers), and grouping is opted into with [Grouping.by]. Both
/// [ListSmith.async] and [ListSmith.sync] take one, so grouping is configured the same way whichever
/// constructor built the list; the two paths differ only in how they order items (see [Grouping.by]).
sealed class Grouping<T extends Object> {
  /// Const base constructor for the sealed hierarchy.
  const Grouping();

  /// Orders [items] into their display sequence. Called once per resolve, on the sync path only.
  ///
  /// [NoGrouping] returns [items] unchanged (no copy when they are already a `List`); [KeyedGrouping]
  /// buckets them so every group is contiguous. The async path never reorders (it cannot, across
  /// pages), so it does not call this. Package-internal: consumers configure grouping via [Grouping.by].
  @internal
  List<T> arrange(Iterable<T> items);

  /// Wraps [itemBuilder] into the per-item builder for one build of the flattened display list.
  ///
  /// [NoGrouping] returns [itemBuilder] unchanged and never calls [flatItems], so an ungrouped list
  /// pays no flatten. [KeyedGrouping] returns a builder that prefixes each group's first item with its
  /// header, reading [flatItems] once for the one-item look-back (and the debug contiguity check), and
  /// stacking the header along [axis]. [flatItems] is a callback precisely so the ungrouped path can
  /// skip producing it. Runs once per build, not per item. Package-internal, like [arrange].
  @internal
  ItemBuilder<T> decorate(
    ItemBuilder<T> itemBuilder, {
    required List<T> Function() flatItems,
    required Axis axis,
  });

  /// Groups items by the key from [groupBy], drawing each section's header with [headerBuilder].
  ///
  /// The key type [K] is inferred from [groupBy] and stays type-safe in [headerBuilder]; it is erased
  /// to `Object` internally, so [ListSmith] needs no second type parameter. A header is rendered above
  /// the first item of each group. Type [groupBy]'s item parameter, or pass a typed function
  /// reference, so `T` and `K` infer rather than widening to `Object` inside a `ListSmith` call.
  ///
  /// Ordering differs by path. A sync list reorders its (filtered) items so every group is contiguous,
  /// in the order each group first appears, keeping item order within a group, so it need not be
  /// pre-sorted. An async list cannot reorder across pages, so it groups items in the order the fetcher
  /// returns them: those items must already arrive grouped by key (all of one group before the next),
  /// or a header repeats wherever a group's items are split apart.
  static Grouping<T> by<T extends Object, K extends Object>({
    required GroupKeyOf<T, K> groupBy,
    required GroupHeaderBuilder<K> headerBuilder,
  }) => KeyedGrouping<T>._(
    groupOf: groupBy,
    headerFor: (context, key) => headerBuilder(context, key as K),
  );
}

/// @docImport '/src/widgets/list_smith.dart';
library;

import 'package:meta/meta.dart';

import '../typedefs/group_header_builder.dart';
import '../typedefs/group_key_of.dart';
import '../utils/grouping_resolver.dart';
import 'group_headers.dart';
import 'group_order_policy.dart';

part 'groupings/keyed_grouping.dart';
part 'groupings/no_grouping.dart';

/// How a list splits its items into labelled sections.
///
/// [NoGrouping] (the default) is flat, no headers. [Grouping.by] turns sections on. Both [ListSmith]
/// constructors take one.
sealed class const Grouping<T extends Object>() {
  /// Const base constructor.
  this;

  /// Orders [items] for display, `.sync` only. Async gathers in [sectionsOver] when a key comes back.
  @internal
  List<T> arrange(Iterable<T> items);

  /// One build's rows in section order, and the header at each group's start, null without groups.
  @internal
  ({List<List<T>> pagedItems, GroupHeaders? groupHeaders}) sectionsOver(List<List<T>> pagedItems);

  /// Pulls an item's group key, null when there are no groups. The edit layer reads it to keep a new or
  /// moved item inside its group.
  @internal
  GroupKeyOf<T, Object>? get groupOf;

  /// Groups items by the key from [groupBy], drawing each section's header with [headerBuilder].
  ///
  /// Type [groupBy]'s parameter, or pass an already-typed function, so `K` infers instead of widening
  /// to `Object`.
  ///
  /// Each group gathers into one section, so items can arrive in any order, even spread over pages.
  /// On `.async` a later page can add to a section above the one being read.
  static Grouping<T> by<T extends Object, K extends Object>({
    required GroupKeyOf<T, K> groupBy,
    required GroupHeaderBuilder<K> headerBuilder,
    @Deprecated('Groups gather on their own now. Remove it, it goes at the next major.')
    GroupOrderPolicy orderPolicy = const RepairHeadersPolicy(),
  }) => KeyedGrouping<T>._(
    groupOf: groupBy,
    headerFor: (context, key) => headerBuilder(context, key as K),
    orderPolicy: orderPolicy,
  );
}

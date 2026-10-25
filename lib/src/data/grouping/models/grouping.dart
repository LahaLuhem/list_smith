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

  /// Orders [items] for display. Sync path only, since async can't reorder across pages.
  @internal
  List<T> arrange(Iterable<T> items);

  /// The headers over [items] for one build, null without groups. [isReversed] puts each after its
  /// group's last item.
  @internal
  GroupHeaders? headersOver(Iterable<T> items, {required bool isReversed});

  /// Pulls an item's group key, null when there are no groups. The edit layer reads it to keep a new or
  /// moved item inside its group.
  @internal
  GroupKeyOf<T, Object>? get groupOf;

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

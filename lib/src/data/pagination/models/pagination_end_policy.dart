/// @docImport 'page_fetcher.dart';
library;

import 'end_context.dart';

part 'policies/explicit_has_more_policy.dart';
part 'policies/fixed_page_count_policy.dart';
part 'policies/stop_on_empty_pages_policy.dart';
part 'policies/stop_on_null_signal_policy.dart';

/// Decides when an async list has reached the end of its data.
///
/// Open on purpose: implement [hasReachedEnd] for a rule of your own (ending on a short last page, say)
/// with no change here. Ships [StopOnEmptyPagesPolicy] (the default), [FixedPageCountPolicy] and
/// [StopOnNullSignalPolicy].
abstract class const PaginationEndPolicy() {
  /// Const base constructor.
  this;

  /// Whether pagination has reached its end, given [context] over the pages loaded so far.
  bool hasReachedEnd(EndContext context);

  /// Whether this policy reads [EndContext.lastPageSignal], so list_smith asserts the fetcher returns
  /// one. Defaults to `false`.
  bool get requiresSignal => false;

  /// Whether the end it reports is where the data ends, rather than a cap. Defaults to `true`.
  bool get stopsAtDataEnd => true;
}

import 'end_context.dart';

part 'policies/explicit_has_more_policy.dart';
part 'policies/fixed_page_count_policy.dart';
part 'policies/stop_on_empty_pages_policy.dart';
part 'policies/stop_on_null_signal_policy.dart';

/// Decides when an async list has reached the end of its data.
///
/// Open on purpose: implement [hasReachedEnd] for a rule of your own (say, ending on a short last
/// page) with no change here. Ships [StopOnEmptyPagesPolicy] (the default), [FixedPageCountPolicy],
/// [ExplicitHasMorePolicy] and [StopOnNullSignalPolicy].
abstract class PaginationEndPolicy {
  /// Const base constructor for subclasses.
  const new();

  /// Whether pagination has reached its end, given [context] over the pages loaded so far.
  bool hasReachedEnd(EndContext context);

  /// Whether this policy reads [EndContext.lastPageSignal]. When true, list_smith asserts the list
  /// was built with a `withSignal` fetcher. Defaults to `false`.
  bool get requiresSignal => false;
}

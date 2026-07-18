import 'end_context.dart';

part 'policies/explicit_has_more_policy.dart';
part 'policies/fixed_page_count_policy.dart';
part 'policies/stop_on_empty_pages_policy.dart';
part 'policies/stop_on_null_signal_policy.dart';

/// Decides when an async list has reached the end of its data.
///
/// An injected, open policy: after each page settles, list_smith rebuilds an [EndContext] from the
/// pages loaded so far and calls [hasReachedEnd]. Ships [StopOnEmptyPagesPolicy] (the default),
/// [FixedPageCountPolicy], and [ExplicitHasMorePolicy]; implement this class to supply your own
/// end-detection (for example ending when the last page came back shorter than the page size) without
/// a change to list_smith.
abstract class PaginationEndPolicy {
  /// Const base constructor for subclasses.
  const PaginationEndPolicy();

  /// Whether pagination has reached its end, given [context] over the pages loaded so far.
  bool hasReachedEnd(EndContext context);

  /// Whether this policy reads the fetcher's end signal ([EndContext.lastPageSignal]), so list_smith
  /// requires a signal-reporting fetcher (`PageFetcher.withSignal`) at construction. Defaults to
  /// `false`; a signal-based policy overrides it to `true`.
  bool get requiresSignal => false;
}

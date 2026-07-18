part of '../pagination_end_policy.dart';

/// Ends pagination when a page's fetcher reports a `null` end signal, after at least one page.
///
/// The cursor-paging counterpart to [ExplicitHasMorePolicy]: pair it with a signal-reporting fetcher
/// (`PageFetcher.withSignal`, and `SearchPageFetcher.withSignal` when the list is searchable) whose
/// signal is the next cursor. The list stops the moment a page returns a `null` cursor, so no trailing
/// fetch is made past the end. A `null` signal before any page has loaded does not end the list; the
/// guard is [EndContext.pageCount] `> 0`.
final class StopOnNullSignalPolicy extends PaginationEndPolicy {
  /// Creates a policy that ends when a page's fetcher returns a `null` signal (e.g. a null cursor).
  const StopOnNullSignalPolicy();

  @override
  bool hasReachedEnd(EndContext context) => context.pageCount > 0 && context.lastPageSignal == null;

  @override
  bool get requiresSignal => true;

  @override
  String toString() => 'StopOnNullSignalPolicy()';
}

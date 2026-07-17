part of '../pagination_end_policy.dart';

/// Ends pagination as soon as a page's fetcher reports there is no more data.
///
/// Pairs with a signal-reporting fetcher (`PageFetcher.withSignal`, and `SearchPageFetcher.withSignal`
/// when the list is searchable) whose signal is a `hasMore` bool: the list stops the moment a page
/// reports `false`, so the trailing empty page a count-based policy fetches to discover the end is
/// never requested. A backend that returns a next-cursor instead can end on a `null` cursor with a
/// one-line custom policy over [EndContext.lastPageSignal]; this built-in covers the boolean case.
final class ExplicitHasMorePolicy extends PaginationEndPolicy {
  /// Creates a policy that ends when a page's fetcher reports `hasMore: false`.
  const ExplicitHasMorePolicy();

  @override
  bool hasReachedEnd(EndContext context) => context.lastPageSignal == false;

  @override
  String toString() => 'ExplicitHasMorePolicy()';
}

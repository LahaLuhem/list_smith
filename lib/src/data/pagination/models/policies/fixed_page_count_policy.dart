part of '../pagination_end_policy.dart';

/// Ends pagination after [pageCount] pages, whatever those pages hold.
///
/// For a capped feed: a "top 100", a teaser of N pages. Emptiness is ignored, unlike [StopOnEmptyPagesPolicy].
final class const FixedPageCountPolicy({
  /// How many pages to fetch before ending. Minimum `1`.
  required final int pageCount,
}) extends PaginationEndPolicy {
  /// Ends after [pageCount] pages.
  this : assert(pageCount >= 1, 'pageCount must be at least 1.');

  @override
  bool hasReachedEnd(EndContext context) => context.pageCount >= pageCount;

  @override
  String toString() => 'FixedPageCountPolicy(pageCount: $pageCount)';
}

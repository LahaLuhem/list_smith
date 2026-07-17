part of '../pagination_end_policy.dart';

/// Ends pagination after a fixed number of pages, [pageCount], whatever those pages contain.
///
/// Fits a capped feed (say a "first few pages" preview) or a source with no natural end signal.
/// Contrast [StopOnEmptyPagesPolicy], which ends when the data runs out; this ends on the page count
/// alone, so a page's emptiness is ignored. [pageCount] must be at least 1.
final class FixedPageCountPolicy extends PaginationEndPolicy {
  /// The number of pages to fetch before ending; at least 1.
  final int pageCount;

  /// Creates a policy that ends after [pageCount] pages.
  const FixedPageCountPolicy({required this.pageCount})
    : assert(pageCount >= 1, 'pageCount must be at least 1.');

  @override
  bool hasReachedEnd(EndContext context) => context.pageCount >= pageCount;

  @override
  String toString() => 'FixedPageCountPolicy(pageCount: $pageCount)';
}

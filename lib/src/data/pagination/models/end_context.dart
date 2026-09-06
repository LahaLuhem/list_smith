/// @docImport 'page_fetcher.dart';
/// @docImport 'pagination_end_policy.dart';
library;

/// The data a [PaginationEndPolicy] sees when deciding whether an async list has reached its end.
///
/// Rebuilt after each page settles from the pages loaded so far, so a policy stays a pure function
/// of its input.
final class EndContext {
  /// The item count of each page fetched so far, in fetch order.
  final List<int> pageItemCounts;

  /// The page size configured on the list, as passed to the fetcher.
  final int pageSize;

  /// The end signal the most recent page's fetcher reported. `null` for a plain [PageFetcher.new],
  /// or before the first page. Signal-based policies read it, count-based ones ignore it.
  final Object? lastPageSignal;

  /// Creates a context over the [pageItemCounts] seen so far and the list's [pageSize].
  const new({required this.pageItemCounts, required this.pageSize, this.lastPageSignal});

  /// The number of pages fetched so far.
  int get pageCount => pageItemCounts.length;

  /// The item count of the most recent page, or `0` when no page has been fetched.
  int get lastPageItemCount => pageItemCounts.isEmpty ? 0 : pageItemCounts.last;

  /// The number of consecutive empty pages at the end of [pageItemCounts].
  int get trailingEmptyRun => pageItemCounts.reversed.takeWhile((count) => count == 0).length;
}

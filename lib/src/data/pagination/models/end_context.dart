/// @docImport 'page_fetcher.dart';
/// @docImport 'pagination_end_policy.dart';
library;

/// What a [PaginationEndPolicy] sees when deciding whether an async list has run out of data.
///
/// Rebuilt after each page lands, so a policy stays a pure function of its input.
final class EndContext {
  /// The item count of each page fetched so far, in fetch order.
  final List<int> pageItemCounts;

  /// The page size the list was configured with.
  final int pageSize;

  /// The end signal the last page's fetcher reported. `null` for a plain [PageFetcher.new], or before
  /// the 1st page.
  final Object? lastPageSignal;

  /// Creates it.
  const new({required this.pageItemCounts, required this.pageSize, this.lastPageSignal});

  /// How many pages have been fetched so far.
  int get pageCount => pageItemCounts.length;

  /// The item count of the most recent page, or `0` before the 1st one.
  int get lastPageItemCount => pageItemCounts.isEmpty ? 0 : pageItemCounts.last;

  /// How many empty pages sit at the end of [pageItemCounts], in a row.
  int get trailingEmptyRun => pageItemCounts.reversed.takeWhile((count) => count == 0).length;
}

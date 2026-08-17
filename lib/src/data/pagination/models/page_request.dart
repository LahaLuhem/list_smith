/// @docImport 'page_fetcher.dart';
/// @docImport 'pagination_end_policy.dart';
library;

/// The inputs of one page fetch, handed to a [PageFetcher] as a single value.
///
/// One object rather than a positional argument list, so a later fetch-time fact arrives as a field
/// instead of a signature change. Built by list_smith per fetch; a consumer only reads it.
base class PageRequest {
  /// The 0-based page to fetch; the first page is `0`.
  final int pageIndex;

  /// How many items to request, the page size configured on the list.
  final int pageSize;

  /// The end signal the previous page's fetcher returned, or `null` for the first page and for a
  /// fetcher that reports none (a plain [PageFetcher.new]). A cursor source reads its cursor here.
  final Object? previousSignal;

  /// Creates a request for the page at [pageIndex].
  const new({required this.pageIndex, required this.pageSize, this.previousSignal});
}

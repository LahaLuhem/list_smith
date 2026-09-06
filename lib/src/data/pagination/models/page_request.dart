/// @docImport 'page_fetcher.dart';
/// @docImport 'pagination_end_policy.dart';
library;

import '../enums/fetch_trigger.dart';

/// The inputs of one page fetch, handed to a [PageFetcher] as a single value. Built per fetch,
/// read-only for a consumer.
base class PageRequest {
  /// The 0-based page to fetch, starting at `0`.
  final int pageIndex;

  /// How many items to request, the page size configured on the list.
  final int pageSize;

  /// The end signal the previous page's fetcher returned, or `null` for the first page and for a
  /// fetcher that reports none (a plain [PageFetcher.new]). A cursor source reads its cursor here.
  final Object? previousSignal;

  /// Why this page was asked for, so a caching repository can route the fetch.
  final FetchTrigger trigger;

  /// Creates a request for the page at [pageIndex].
  const new({
    required this.pageIndex,
    required this.pageSize,
    required this.trigger,
    this.previousSignal,
  });
}

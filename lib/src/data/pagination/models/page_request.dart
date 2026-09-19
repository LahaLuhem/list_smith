/// @docImport 'page_fetcher.dart';
/// @docImport 'pagination_end_policy.dart';
library;

import '../enums/fetch_trigger.dart';

/// The inputs of one page fetch, handed to a [PageFetcher]. Read-only.
base class PageRequest {
  /// The 0-based page to fetch.
  final int pageIndex;

  /// How many items to ask for.
  final int pageSize;

  /// The end signal the previous page's fetcher returned, or `null` for the 1st page and for a fetcher
  /// that reports none (a plain [PageFetcher.new]). A cursor source reads its cursor here.
  final Object? previousSignal;

  /// Why this page was asked for, so a caching repository can route the fetch.
  final FetchTrigger trigger;

  /// Creates it.
  const new({
    required this.pageIndex,
    required this.pageSize,
    required this.trigger,
    this.previousSignal,
  });
}

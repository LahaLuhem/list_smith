/// @docImport 'page_fetcher.dart';
/// @docImport 'pagination_end_policy.dart';
library;

import '../enums/fetch_trigger.dart';

/// The inputs of one page fetch, handed to a [PageFetcher]. Read-only.
base class const PageRequest({
  /// The 0-based page to fetch.
  required final int pageIndex,

  /// How many items to ask for.
  required final int pageSize,

  /// Why this page was asked for, so a caching repository can route the fetch.
  required final FetchTrigger trigger,

  /// The end signal the previous page's fetcher returned, or `null` for the 1st page and for a fetcher
  /// that reports none (a plain [PageFetcher.new]). A cursor source reads its cursor here.
  final Object? previousSignal,
}) {
  /// Creates it.
  this;
}

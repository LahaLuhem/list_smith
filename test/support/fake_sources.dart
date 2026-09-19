import 'package:list_smith/list_smith.dart';

/// A [PageFetcher] serving each entry of [pages] as one page by 0-based index, then empty pages, which
/// the default end policy reads as the end. Repeat items across entries to model overlapping pages.
PageFetcher<T> pagedFetcher<T extends Object>(List<List<T>> pages) => PageFetcher(
  (request) async => request.pageIndex < pages.length ? pages[request.pageIndex] : <T>[],
);

/// The [SearchPageFetcher] twin of [pagedFetcher]. The `query` is ignored: it only has to be non-empty
/// to drive search mode.
SearchPageFetcher<T> pagedSearchFetcher<T extends Object>(List<List<T>> pages) => SearchPageFetcher(
  (request) async => request.pageIndex < pages.length ? pages[request.pageIndex] : <T>[],
);

/// A case-insensitive substring [SyncSearchPredicate], the matcher the sync-search tests share.
bool containsIgnoreCase(String item, String query) =>
    item.toLowerCase().contains(query.toLowerCase());

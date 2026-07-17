import 'package:list_smith/list_smith.dart';

/// A [PageFetcher] that serves each entry of [pages] as one page by 0-based index, then empty pages
/// (which the default end policy reads as the end). Lets a test declare its paged data as a list of
/// pages instead of a hand-rolled `switch`, and models overlapping pages by repeating items across
/// entries.
PageFetcher<T> pagedFetcher<T extends Object>(List<List<T>> pages) =>
    (pageIndex, _) async => pageIndex < pages.length ? pages[pageIndex] : <T>[];

/// A [SearchPageFetcher] twin of [pagedFetcher]: serves each entry of [pages] as one search page by
/// 0-based index, then empty pages. The `query` is ignored (it only has to be non-empty to drive
/// search mode), so a search test can declare overlapping search pages the same way [pagedFetcher]
/// does for the normal path.
SearchPageFetcher<T> pagedSearchFetcher<T extends Object>(List<List<T>> pages) =>
    (_, pageIndex, _) async => pageIndex < pages.length ? pages[pageIndex] : <T>[];

/// A case-insensitive substring [SyncSearchPredicate], the matcher the sync-search tests share.
bool containsIgnoreCase(String item, String query) =>
    item.toLowerCase().contains(query.toLowerCase());

## [Unreleased]
### Added
- \[#28\] Add a depth-preserving pull-to-refresh strategy (ReloadToCurrentDepth)

### Fixed
- \[#26\] Add EmptyPageBehaviour to page past empty pages

## [0.1.0] - 2026-07-19
### Added
- \[#7\] groupBy + groupByHeaderBuilder
- \[#5\] Android verified
- \[#1\] ExplicitHasMorePolicy: end pagination when the fetcher reports hasMore is false, so a trailing empty page is never fetched to find the end.
- \[#1\] PageFetcher.withSignal and SearchPageFetcher.withSignal: return (items, signal) to report an end signal (a hasMore flag or a next-cursor) to the end policy.
- \[#1\] Implement your own PaginationEndPolicy over EndContext for custom end-detection, e.g. stop on a short last page or a null next-cursor.
- \[#14\] Cursor-driven pagination: PageFetcher.withSignal and SearchPageFetcher.withSignal now receive the previous page's signal as previousSignal, so a cursor source drives the next fetch from the cursor the previous page returned.
- \[#14\] StopOnNullSignalPolicy: end pagination when the fetcher returns a null cursor (the cursor-paging counterpart to ExplicitHasMorePolicy).
- \[#14\] PaginationEndPolicy.requiresSignal: a policy declares whether it reads the fetcher's end signal, so a signal-reporting fetcher is required at construction.

### Changed
- \[#4\] Verify regression + Bump python versions
- \[#1\] BREAKING: PageFetcher and SearchPageFetcher are now classes, not function typedefs. Wrap your fetch function, e.g. fetchPage: PageFetcher((pageIndex, pageSize) => ...).
- \[#1\] PaginationEndPolicy is now an open interface: end-detection is a public hasReachedEnd(EndContext), previously an internal resolver over per-page counts.
- \[#16\] Grouping polymorphic dispatch
- \[#3\] BREAKING: pull-to-refresh is now the refresh: seam (PullToRefresh default, NoRefresh to disable), replacing the pullToRefresh bool. Migrate pullToRefresh: false to refresh: NoRefresh().
- \[#3\] BREAKING: the custom pull-to-refresh indicator moved from AsyncListSurfaces.refreshBuilder to PullToRefresh(refreshBuilder:). Migrate surfaces: AsyncListSurfaces(refreshBuilder: fn) to refresh: PullToRefresh(refreshBuilder: fn).
- \[#3\] BREAKING: async search is now the search: seam (AsyncSearch(fetchPage:, cachePolicy:), default NoSearch), replacing searchFetchPage and searchCachePolicy. Migrate searchFetchPage: fn, searchCachePolicy: p to search: AsyncSearch(fetchPage: fn, cachePolicy: p).

### Fixed
- \[#2\] keep pagination alive past an all-duplicate page

## [0.0.1] - 2026-07-15
### Added
- `ListSmith.async`: async pagination and pull-to-refresh over a page fetcher, with neutral, overridable widgets-layer surfaces.
- `ListSmith.sync`: client-side search over an in-memory list via a search predicate.
- Async two-view search via `searchFetchPage`, with a sealed `SearchCachePolicy` (`ReplaceCachePolicy` default, `KeepCachePolicy`).
- Swappable pagination end-detection: `StopOnEmptyPagesPolicy` (default) and `FixedPageCountPolicy`.
- Opt-in `itemId` de-duplication for items repeated across overlapping pages.
- Lifecycle observer `ListSmithObserver` (and `LoggingListSmithObserver`) for page-load, error, refresh, and search events.

[Unreleased]: https://github.com/LahaLuhem/list_smith/compare/0.1.0...HEAD
[0.1.0]: https://github.com/LahaLuhem/list_smith/compare/0.0.1...0.1.0
[0.0.1]: https://github.com/LahaLuhem/list_smith/releases/tag/0.0.1

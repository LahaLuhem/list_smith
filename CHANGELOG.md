## [Unreleased]
### Added
- \[#7\] groupBy + groupByHeaderBuilder
- \[#5\] Android verified
- \[#1\] ExplicitHasMorePolicy: end pagination when the fetcher reports hasMore is false, so a trailing empty page is never fetched to find the end.
- \[#1\] PageFetcher.withSignal and SearchPageFetcher.withSignal: return (items, signal) to report an end signal (a hasMore flag or a next-cursor) to the end policy.
- \[#1\] Implement your own PaginationEndPolicy over EndContext for custom end-detection, e.g. stop on a short last page or a null next-cursor.

### Changed
- \[#4\] Verify regression + Bump python versions
- \[#1\] BREAKING: PageFetcher and SearchPageFetcher are now classes, not function typedefs. Wrap your fetch function, e.g. fetchPage: PageFetcher((pageIndex, pageSize) => ...).
- \[#1\] PaginationEndPolicy is now an open interface: end-detection is a public hasReachedEnd(EndContext), previously an internal resolver over per-page counts.

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

[Unreleased]: https://github.com/LahaLuhem/list_smith/compare/0.0.1...HEAD
[0.0.1]: https://github.com/LahaLuhem/list_smith/releases/tag/0.0.1

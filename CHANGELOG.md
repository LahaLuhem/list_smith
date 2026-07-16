## [Unreleased]
### Added
- \[#7\] groupBy + groupByHeaderBuilder

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

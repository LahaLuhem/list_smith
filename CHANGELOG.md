## [2.0.0] - 2026-10-05
### Added
- \[#24\] In-place item edits (upsert / remove) without a refetch
- \[#75\] Rows follow their item, and edits can animate them in and out
- \[#80\] `pullableSurfaces` controls conditions for interacting with the RefreshIndicator

### Changed
- \[#74\] Pull indicator follows the pull's side and physics, adds `pullDirection` and `indicatorExtent`
- \[#75\] **BREAKING:** ListSmith.async now requires `itemIdGetter`, which replaces the optional `itemId`.
- \[#75\] **BREAKING:** the `ItemId` typedef is now `ItemIdGetter`.
- \[#69\] **BREAKING:** PullToRefresh's `refreshBuilder` is now `indicatorBuilder` (RefreshIndicatorBuilder), with no child argument. ListSmithRefreshPhase drops `.idle`.
- \[#24\] **BREAKING:** ListSmithController is now typed by its list's items.
- **BREAKING:** AsyncListSurfaces, ListScrollConfig and ListSmithRefreshState are `final`
- \[#80\] **BREAKING:** ErrorBuilder and ListSmithObserver.onError take an Exception. A fetcher's Error now reaches your app instead of the error surface.

### Fixed
- \[#69\] Idle lists stop drawing frames: `indicatorBuilder` replaces `refreshBuilder`
- \[#72\] A row keeps its state, and a swipe in progress, when rows above it come or go
- \[#80\] No pull or extra request while the 1st page loads, and no list stuck on its loader after quick restarts
- \[#80\] The 1st-page loader fills one screen and stays still, so a LayoutBuilder in it works

### Removed
- \[#80\] refresh(), invalidate() and reset() wait for the fresh page. A short list takes a pull with any scroll setup. infinite\_scroll\_pagination is gone.

## [1.0.0] - 2026-09-11
### Added
- \[#23\] Add ListSmithController to refresh an async list from code (a button, a tab re-tap)
- \[#59\] ListSmithController gains invalidate(), which re-reads every loaded page in place, and reset(), which starts over from page one. Both report FetchTrigger.invalidated.

### Changed
- \[#45\] **BREAKING:** fetch closures take one PageRequest, or SearchPageRequest when searching, instead of positional arguments. The old arguments are the request fields under the same names: pageIndex, pageSize, previousSignal, plus query on a search. Watch your interpolations, "$pageIndex" becomes "${request.pageIndex}".
- \[#59\] **BREAKING:** ListSmithObserver.onRefresh() is now onReload(FetchTrigger trigger), and it fires for every reload the engine starts, not just a pull. Rename your override.
- \[#59\] **BREAKING:** EmptyPageContext.moreAvailable is now isMoreAvailable. Only a custom EmptyPageBehaviour reads it.
- **BREAKING:** the SDK floor is now Dart 3.13 and Flutter 3.47, up from Dart 3.12 and Flutter 3.44.
- \[#37\] Grouping: one header for a group that straddles a page boundary, in release too

### Fixed
- \[#35\] Drop the in-flight fetch when the paging state is swapped wholesale
- \[#60\] KeepCachePolicy: a refresh, invalidate() or reset() while searching now reaches the kept feed

## [0.1.1] - 2026-07-20
### Added
- \[#28\] Add a depth-preserving pull-to-refresh strategy (ReloadToCurrentDepth)
- \[#25\] SyncSearchPredicates: ready-made sync-search predicate builders. fields (contains), prefix (starts-with), exact (equals), allTerms (multi-word AND), and any/every to combine predicates.

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

[2.0.0]: https://github.com/LahaLuhem/list_smith/compare/1.0.0...2.0.0
[1.0.0]: https://github.com/LahaLuhem/list_smith/compare/0.1.1...1.0.0
[0.1.1]: https://github.com/LahaLuhem/list_smith/compare/0.1.0...0.1.1
[0.1.0]: https://github.com/LahaLuhem/list_smith/compare/0.0.1...0.1.0
[0.0.1]: https://github.com/LahaLuhem/list_smith/releases/tag/0.0.1

import 'search_cache_policy.dart';

/// Maps a [SearchCachePolicy] and a mode transition to the [CacheAction] the search view runs.
///
/// Kept as an unexported extension in its own file so the policy stays pure data while the "what to
/// do on a transition" decision is a small, controller-free unit that can be unit-tested directly
/// (the same split as `PaginationEndPolicyResolver`).
extension SearchCachePolicyResolver on SearchCachePolicy {
  /// The action for a transition from [wasSearching] to [isSearching] under this policy.
  ///
  /// Replace always reloads clean. Keep snapshots the normal list when entering search and restores
  /// it when leaving; a search-to-search change (both searching) reloads clean.
  CacheAction actionFor({required bool wasSearching, required bool isSearching}) => switch (this) {
    ReplaceCachePolicy() => .refresh,
    KeepCachePolicy() when !wasSearching && isSearching => .snapshotThenRefresh,
    KeepCachePolicy() when wasSearching && !isSearching => .restoreNormal,
    KeepCachePolicy() => .refresh,
  };
}

/// What the async search view should do to its paging controller on a normal ↔ search transition.
///
/// The pure decision produced by [SearchCachePolicyResolver]; the view executes it against the paging
/// controller (which this decision stays free of, so it is unit-tested directly).
enum CacheAction {
  /// Clear the paging state and refetch page 0: a clean load of the new mode.
  refresh,

  /// Snapshot the current (normal-mode) paging state, then [refresh] into the new search.
  snapshotThenRefresh,

  /// Restore the snapshotted normal-mode paging state; if there is none, fall back to [refresh].
  restoreNormal,
}

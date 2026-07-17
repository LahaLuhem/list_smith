import '../enums/cache_action.dart';
import '../models/search_cache_policy.dart';

/// Maps a [SearchCachePolicy] and a mode transition to the [CacheAction] the search view runs.
///
/// Kept as an unexported extension in its own file so the policy stays pure data while the "what to
/// do on a transition" decision is a small, controller-free unit that can be unit-tested directly
/// (the same split as `PaginationEndPolicy.hasReachedEnd`).
extension SearchCachePolicyResolverExtension on SearchCachePolicy {
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

import '../enums/cache_action.dart';
import '../models/search_cache_policy.dart';

/// Maps a [SearchCachePolicy] and a mode transition to the [CacheAction] the search view runs.
///
/// Unexported, in its own file, so the policy stays pure data and the decision stays a small
/// controller-free unit that unit-tests directly.
extension SearchCachePolicyResolverExtension on SearchCachePolicy {
  /// The action for a transition from [wasSearching] to [isSearching] under this policy.
  ///
  /// Replace always reloads clean. Keep snapshots the normal list on the way in and restores it on
  /// the way out. A search-to-search change reloads clean either way.
  CacheAction actionFor({required bool wasSearching, required bool isSearching}) => switch (this) {
    ReplaceCachePolicy() => .refresh,
    KeepCachePolicy() when !wasSearching && isSearching => .snapshotThenRefresh,
    KeepCachePolicy() when wasSearching && !isSearching => .restoreNormal,
    KeepCachePolicy() => .refresh,
  };
}

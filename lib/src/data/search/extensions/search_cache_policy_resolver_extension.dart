import '../enums/cache_action.dart';
import '../models/search_cache_policy.dart';

/// Maps a [SearchCachePolicy] and a mode change to the [CacheAction] the search view runs.
///
/// Its own file, so the policy stays pure data and this stays a small unit that tests directly.
extension SearchCachePolicyResolverExtension on SearchCachePolicy {
  /// The action for a move from [wasSearching] to [isSearching] under this policy.
  ///
  /// Replace always reloads clean. Keep puts the feed aside on the way in and back on the way out. A
  /// search-to-search change reloads clean either way.
  CacheAction actionFor({required bool wasSearching, required bool isSearching}) => switch (this) {
    ReplaceCachePolicy() => .refresh,
    KeepCachePolicy() when !wasSearching && isSearching => .snapshotThenRefresh,
    KeepCachePolicy() when wasSearching && !isSearching => .restoreNormal,
    KeepCachePolicy() => .refresh,
  };
}

/// @docImport '../extensions/search_cache_policy_resolver_extension.dart';
library;

/// What the async search view does to its paging controller when the list enters or leaves search.
///
/// The pure half, worked out by [SearchCachePolicyResolverExtension]. The view runs it.
enum CacheAction {
  /// Clear the paging state and refetch page 0: a clean load of the new mode.
  refresh,

  /// Put the current (normal-mode) paging state aside, then [refresh] into the new search.
  snapshotThenRefresh,

  /// Put the saved normal-mode paging state back, falling back to [refresh] when there is none.
  restoreNormal,
}

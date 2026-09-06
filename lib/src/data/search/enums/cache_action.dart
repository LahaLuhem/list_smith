/// @docImport '../extensions/search_cache_policy_resolver_extension.dart';
library;

/// What the async search view does to its paging controller when the list enters or leaves search.
///
/// The pure half, produced by [SearchCachePolicyResolverExtension]. The view runs it against the
/// controller.
enum CacheAction {
  /// Clear the paging state and refetch page 0: a clean load of the new mode.
  refresh,

  /// Snapshot the current (normal-mode) paging state, then [refresh] into the new search.
  snapshotThenRefresh,

  /// Restore the snapshotted normal-mode paging state, falling back to [refresh] when there is
  /// none.
  restoreNormal,
}

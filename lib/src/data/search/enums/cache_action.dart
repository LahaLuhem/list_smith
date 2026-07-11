/// @docImport '../extensions/search_cache_policy_resolver_extension.dart';
library;

/// What the async search view should do to its paging controller on a normal ↔ search transition.
///
/// The pure decision produced by [SearchCachePolicyResolverExtension]; the view executes it against the paging
/// controller (which this decision stays free of, so it is unit-tested directly).
enum CacheAction {
  /// Clear the paging state and refetch page 0: a clean load of the new mode.
  refresh,

  /// Snapshot the current (normal-mode) paging state, then [refresh] into the new search.
  snapshotThenRefresh,

  /// Restore the snapshotted normal-mode paging state; if there is none, fall back to [refresh].
  restoreNormal,
}

/// @docImport '../models/reload.dart';
library;

/// How a [ReloadToCurrentDepth] reload settles when a page-fetch fails (after the fetcher's own retries).
///
/// Applies to index-based sources reloaded in parallel. A `withSignal` source reloads sequentially and
/// is always atomic (a broken cursor chain can't be partially committed), so this is ignored there.
enum ReloadOnError {
  /// Keep every page that reloaded and leave the rest as they were: best-effort, the default. Resilient
  /// to isolated failures, but a stale page beside fresh neighbours can seam (a configured `itemId`
  /// de-dups the duplicates; gaps heal on the next refresh).
  commitSucceeded,

  /// Commit only if every page reloads. On any failure keep the pre-refresh data untouched and report
  /// the error, so the list never mixes fresh and stale pages.
  allOrNothing,
}

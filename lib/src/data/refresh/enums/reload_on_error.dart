/// @docImport '../models/reload.dart';
library;

/// How a [ReloadToCurrentDepth] reload settles when a page fetch fails, after the fetcher's own retries.
///
/// Index-based sources only. A `withSignal` source reloads in order and is always atomic, since a broken
/// cursor chain can't be half-committed, so this is ignored there.
enum ReloadOnError {
  /// Keep every page that reloaded and leave the rest as they were. Best-effort, the default.
  ///
  /// A stale page beside fresh neighbours can seam: `itemId` de-dups the duplicates, gaps heal on the
  /// next refresh.
  commitSucceeded,

  /// Commit only if every page reloads. On any failure keep the old data and report the error, so the
  /// list never mixes fresh and stale pages.
  allOrNothing,
}

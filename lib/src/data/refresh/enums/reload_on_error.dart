/// @docImport '../models/reload.dart';
library;

/// How a [ReloadToCurrentDepth] reload used to settle a failed page.
@Deprecated('Does nothing now. Remove it, it goes at the next major.')
enum ReloadOnError() {
  /// Kept the pages that reloaded, beside the old one that failed.
  commitSucceeded,

  /// Committed only once every page reloaded, as every depth reload now does.
  allOrNothing;

  @Deprecated('Does nothing now. Remove it, it goes at the next major.')
  this;
}

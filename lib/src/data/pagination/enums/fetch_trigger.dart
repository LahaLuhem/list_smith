/// @docImport '/src/data/control/control.dart';
/// @docImport '../models/page_request.dart';
library;

/// Why list_smith asked for a page, carried on every [PageRequest].
///
/// A fact to route on, not an instruction: what a cache should do about it is your call.
enum FetchTrigger() {
  /// The 1st page of a cold list.
  initialLoad,

  /// The next page, because the user neared the end (or an empty page was paged past).
  nextPage,

  /// A pull-to-refresh, or [ListSmithController.refresh], which does the same thing.
  refresh,

  /// A re-fetch of the page whose last attempt threw.
  retry,

  /// A reload from a committed query change, entering or leaving search included.
  queryChanged,

  /// Your data changed locally, so a page gets read again: you called [ListSmithController.invalidate]
  /// or [ListSmithController.reset], or removed rows above it. Treat it like a cold page, not a refresh.
  invalidated,
}

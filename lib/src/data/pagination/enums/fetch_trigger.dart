/// @docImport '/src/data/control/models/list_smith_controller.dart';
/// @docImport '/src/data/pagination/models/page_request.dart';
library;

/// Why list_smith asked for a page, carried on every [PageRequest].
///
/// A fact to route on, not an instruction: what a cache should do about it is your call.
enum FetchTrigger {
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

  /// A re-read you asked for via [ListSmithController.invalidate] or [ListSmithController.reset], because
  /// your data changed locally. Treat it like a cold page, not a refresh.
  invalidated,
}

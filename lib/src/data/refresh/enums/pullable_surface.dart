/// @docImport '../models/refresh.dart';
library;

/// A surface shown instead of the rows, which [PullToRefresh.pullableSurfaces] can let a pull refresh.
enum PullableSurface() {
  /// The 1st-page error, so a pull retries it.
  error,

  /// The empty list, a search's no-results included, so a pull asks again.
  empty,
}

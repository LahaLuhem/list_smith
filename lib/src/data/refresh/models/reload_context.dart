/// @docImport 'reload.dart';
library;

import 'package:meta/meta.dart';

/// The handle a [Reload] works through, a `BuildContext` for a reload.
///
/// One per reload, so it can read depth, fetch and commit without touching the paging controller.
/// Nothing here empties the list, so rows stay until their replacement lands.
@internal
abstract interface class ReloadContext<T extends Object>._() {
  /// How many pages were loaded when the reload began. Never 0, since the engine resets an empty list.
  int get depth;

  /// Whether the source threads a per-page signal, which forces a sequential reload whatever the
  /// strategy asked for.
  bool get isSignalBased;

  /// Whether the list moved on since this reload began: a reset, a committed query, or the list is
  /// gone. A stale [commit] is dropped, so stop fetching once this is true.
  bool get isStale;

  /// Fetches page [index] given the [previousSignal] from the page before it, null for index sources
  /// and the 1st page. Throws if the fetch fails.
  Future<(List<T>, Object?)> fetch(int index, Object? previousSignal);

  /// Replaces the loaded pages with [pages] in one go, recording [lastSignal] as the new end signal. It
  /// may read pages again first, so await it.
  Future<void> commit(List<List<T>> pages, {Object? lastSignal});
}

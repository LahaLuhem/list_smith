/// @docImport 'reload.dart';
library;

import 'package:meta/meta.dart';

/// The handle a [Reload] works through, a `BuildContext` for a reload.
///
/// One per reload, so it can read depth, fetch, and commit or reset without ever touching the paging
/// controller.
@internal
abstract interface class ReloadContext<T extends Object>._() {
  /// The pages loaded when the reload began, in order. Its length is the depth to reload to, and a
  /// best-effort reload reuses an entry whose re-fetch failed. Hand that entry back as is, not a copy,
  /// so it keeps its read stamp.
  List<List<T>> get loadedPages;

  /// Whether the source threads a per-page signal, which forces a sequential, atomic reload whatever
  /// the strategy asked for.
  bool get isSignalBased;

  /// Whether the list moved on since this reload began: a reset, a query change, or the list is gone.
  /// A stale [commit] is dropped, so stop fetching once this is true.
  bool get isStale;

  /// Fetches page [index] given the [previousSignal] from the page before it, null for index sources
  /// and the 1st page. Throws if the fetch fails.
  Future<(List<T>, Object?)> fetch(int index, Object? previousSignal);

  /// Replaces the loaded pages with [pages] in one go, recording [lastSignal] as the new end signal.
  void commit(List<List<T>> pages, {Object? lastSignal});

  /// Throws away the loaded pages and re-fetches only the 1st, the [ResetToFirstPage] behaviour.
  /// Completes once that page lands or fails, or the list moves on first.
  Future<void> reset();
}

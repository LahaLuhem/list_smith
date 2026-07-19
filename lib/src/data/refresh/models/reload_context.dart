/// @docImport 'reload.dart';
library;

import 'package:meta/meta.dart';

/// The capability handle a [Reload] works through, the `BuildContext` analogue for a reload.
///
/// The async engine implements this and hands it to [Reload.run]; a reload reads the current depth,
/// fetches pages, and commits or resets through it, never touching the paging controller itself.
/// Internal: the [Reload] hierarchy is sealed, so only list_smith's own reloads ever consume it.
@internal
abstract interface class ReloadContext<T extends Object> {
  /// The pages currently loaded, in order. Its length is the depth to reload to; a best-effort reload
  /// reuses an entry when that page's re-fetch fails.
  List<List<T>> get loadedPages;

  /// Whether the source threads a per-page signal (built with `withSignal`), which forces a sequential,
  /// atomic reload regardless of the strategy's concurrency and error settings.
  bool get isSignalBased;

  /// Fetches page [index] given the [previousSignal] from the page before it (null for index sources
  /// and the first page), returning the page's items and its own signal. Throws if the fetch fails.
  Future<(List<T>, Object?)> fetch(int index, Object? previousSignal);

  /// Replaces the loaded pages with [pages] atomically, recording [lastSignal] as the new end signal.
  void commit(List<List<T>> pages, {Object? lastSignal});

  /// Discards the loaded pages and re-fetches only the first (the [ResetToFirstPage] behaviour).
  void reset();
}

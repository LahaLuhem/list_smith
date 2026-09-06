/// @docImport 'reload.dart';
library;

import 'package:meta/meta.dart';

/// The handle a [Reload] works through, the `BuildContext` analogue for a reload.
///
/// The engine implements it and hands it to [Reload.run], so a reload reads depth, fetches, and
/// commits or resets without touching the paging controller. Internal, since [Reload] is sealed.
@internal
abstract interface class ReloadContext<T extends Object> {
  /// The pages currently loaded, in order. Its length is the depth to reload to, and a best-effort
  /// reload reuses an entry whose re-fetch failed.
  List<List<T>> get loadedPages;

  /// Whether the source threads a per-page signal, which forces a sequential, atomic reload whatever
  /// the strategy's concurrency and error settings say.
  bool get isSignalBased;

  /// Fetches page [index] given the [previousSignal] from the page before it (null for index sources
  /// and the first page), returning the page's items and its own signal. Throws if the fetch fails.
  Future<(List<T>, Object?)> fetch(int index, Object? previousSignal);

  /// Replaces the loaded pages with [pages] atomically, recording [lastSignal] as the new end signal.
  void commit(List<List<T>> pages, {Object? lastSignal});

  /// Discards the loaded pages and re-fetches only the first (the [ResetToFirstPage] behaviour).
  void reset();
}

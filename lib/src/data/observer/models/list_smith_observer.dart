// No-op defaults are the design: a subclass overrides only what it cares about.
// ignore_for_file: no-empty-block

/// @docImport '/src/widgets/list_smith.dart';
/// @docImport 'sinks/logging_list_smith_observer.dart';
library;

import '/src/data/pagination/enums/fetch_trigger.dart';

/// Lifecycle sink for a [ListSmith.async] list: logging, telemetry, analytics.
///
/// Pass it as `ListSmith.async(observer: ...)`. Every method has a no-op default, so override only what
/// you care about. [LoggingListSmithObserver] is the ready-made one.
///
/// ```dart
/// final class _MyObserver extends ListSmithObserver {
///   const _MyObserver(this._log);
///   final void Function(String) _log;
///
///   @override
///   void onError(Object error, StackTrace stackTrace) => _log('list load failed: $error');
/// }
/// ```
///
/// Callbacks run synchronously on the fetch, reload and query-commit paths, never during `build`, so
/// keep them cheap or you stall the list. Async only: a `.sync` list has nothing to watch.
abstract base class ListSmithObserver {
  /// Const default constructor.
  const new();

  /// A page came back, before it reaches the list. [pageIndex] is 0-based.
  ///
  /// An empty page still fires. Whether that's the end is the end policy's call.
  void onPageLoaded(int pageIndex, int itemCount, {required bool isSearchMode}) {}

  /// A page fetch threw. Nothing is swallowed, the list still shows its error surface.
  void onError(Object error, StackTrace stackTrace) {}

  /// A reload started, before any of its pages is asked for. [trigger] is what those pages report.
  ///
  /// Joining a reload already running fires nothing, and neither does a restored cached feed unless
  /// it owes a reload asked while searching.
  void onReload(FetchTrigger trigger) {}

  /// A new search [query] took effect, after trimming, gating and debounce.
  ///
  /// What's actually searched on, not every keystroke. Empty means back to the normal feed. The query
  /// a list is built with doesn't fire, only changes do.
  void onQueryCommitted(String query) {}

  /// The list crossed between normal and search mode. The edge only: [onQueryCommitted] fires on every
  /// committed change, one search replacing another included.
  void onSearchModeChanged({required bool isSearchMode}) {}
}

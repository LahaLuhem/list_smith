// No-op defaults are the design: a subclass overrides only what it cares about.
// ignore_for_file: no-empty-block

/// @docImport '/src/widgets/list_smith.dart';
/// @docImport 'sinks/logging_list_smith_observer.dart';
library;

import '/src/data/pagination/enums/fetch_trigger.dart';

/// Lifecycle observer for a [ListSmith.async] list: an optional, injected sink for logging,
/// telemetry, or analytics.
///
/// Wired through `ListSmith.async(observer: ...)`, `null` (the default) being silent. Every callback
/// gets plain values (page indices, counts, the committed query, the error), never the paging
/// controller or a dependency type, so wiring up diagnostics can't reach an internal handle.
///
/// Each method has a no-op default body, so override only the events you want. Extend, never
/// implement: `abstract base` means a later minor release can add an event without breaking you.
/// [LoggingListSmithObserver] is the ready-made sink.
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
/// Callbacks fire synchronously from the fetch, reload, and query-commit paths, never during
/// `build`, so heavy work in an override stalls that path. Keep them cheap. Async only:
/// [ListSmith.sync] has no fetch, refresh, or controller to watch, and you already own its query.
abstract base class ListSmithObserver {
  /// Const default constructor.
  const new();

  /// Called after a page is fetched and materialised, before it reaches the list.
  ///
  /// [pageIndex] is 0-based, [itemCount] is what that page returned, and [isSearchMode] says which
  /// fetcher it came from. An empty page still fires: whether that is the end is the end policy's
  /// call.
  void onPageLoaded(int pageIndex, int itemCount, {required bool isSearchMode}) {}

  /// Called when a page fetch throws, with the [error] and [stackTrace] as thrown. Nothing is
  /// swallowed, the list still shows its error surface.
  void onError(Object error, StackTrace stackTrace) {}

  /// Called when a reload starts, before any page of it is asked for. [trigger] is what those pages
  /// will report: `.refresh` for a pull or `refresh()`, `.queryChanged` for a committed query change.
  /// Joining a reload already running fires nothing, nor does a `KeepCachePolicy` restore unless it
  /// pays for a reload asked while searching.
  void onReload(FetchTrigger trigger) {}

  /// Called when a new search [query] takes effect, after trimming, gating, and debounce.
  ///
  /// The query actually searched on, not the per-keystroke value, so it fires once typing settles.
  /// Empty means back to the normal feed. The query a list is built with doesn't fire, only changes.
  void onQueryCommitted(String query) {}

  /// Called when the list crosses between normal and search mode, [isSearchMode] being the new one.
  ///
  /// The edge only. [onQueryCommitted] fires on every committed change, one search replacing
  /// another included.
  void onSearchModeChanged({required bool isSearchMode}) {}
}

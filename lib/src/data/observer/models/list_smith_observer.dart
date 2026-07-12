// No-op defaults are the design: a subclass overrides only the events it cares about. See the class dartdoc.
// ignore_for_file: no-empty-block

/// @docImport '/src/widgets/list_smith.dart';
/// @docImport 'sinks/logging_list_smith_observer.dart';
library;

/// Lifecycle observer for a [ListSmith.async] list: an optional, injected sink for logging,
/// telemetry, or analytics.
///
/// Wired through `ListSmith.async(observer: ...)`; `null` (the default) is silent. The observer stays
/// **fully hidden**: every callback receives plain values (page indices, counts, the committed query,
/// the error), never the paging controller, the paging state, or any dependency type, so wiring up
/// diagnostics can never reach an internal handle.
///
/// Designed for **selective verbosity by partial override**: every method has a no-op default body,
/// so a subclass overrides only the events it wants and the rest cost nothing.
///
/// Extend, don't implement: the class is `abstract base`, so a later minor release can add a new
/// lifecycle event as a no-op method without breaking existing subclasses. For a ready-made sink that
/// logs every event, see [LoggingListSmithObserver].
///
/// The events are **async-only**. [ListSmith.sync] exposes no observer: an in-memory list has no
/// controller, fetch, or refresh to observe, and the consumer already owns the query it filters on.
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
/// Callbacks fire synchronously from the fetch, refresh, and debounced-query paths, never during
/// `build`. Heavy synchronous work in an override therefore stalls that path; keep overrides cheap,
/// or hand off to async work.
abstract base class ListSmithObserver {
  /// Const default constructor; subclasses are encouraged to be const.
  const ListSmithObserver();

  /// Called after a page is fetched and materialised, before it is handed to the list.
  ///
  /// [pageIndex] is the 0-based page just loaded, [itemCount] how many items it returned, and
  /// [isSearchMode] whether it came from the search fetcher rather than the normal one. An empty page
  /// still fires; whether that means end-of-data is the end policy's concern, not this event's.
  void onPageLoaded(int pageIndex, int itemCount, {required bool isSearchMode}) {
    // No-op default; override to observe successful page loads.
  }

  /// Called when a page fetch throws, with the [error] and [stackTrace] as thrown.
  ///
  /// The error is not swallowed: the list still shows its error surface. This event is the clean way
  /// to report a load failure that the hidden controller would otherwise keep out of reach.
  void onError(Object error, StackTrace stackTrace) {
    // No-op default; override to report load failures.
  }

  /// Called when a pull-to-refresh gesture triggers a reload, just before the list resets.
  void onRefresh() {
    // No-op default; override to observe pull-to-refresh.
  }

  /// Called when a new search [query] takes effect, after trimming, min-length gating, and debounce.
  ///
  /// This is the committed query the list actually searched on, not the raw per-keystroke value, so
  /// it fires once the input settles; an empty [query] means the list returned to normal mode. It
  /// does not fire for the query a list is first built with, only for later changes.
  void onQueryCommitted(String query) {
    // No-op default; override to observe committed search queries.
  }

  /// Called when the list crosses between normal and search mode, [isSearchMode] being the new mode.
  ///
  /// The "entered / left search" edge: it fires only on the transition, whereas [onQueryCommitted]
  /// fires on every committed query change, including one search replacing another.
  void onSearchModeChanged({required bool isSearchMode}) {
    // No-op default; override to observe normal <-> search transitions.
  }
}

/// @docImport '/src/data/observer/models/list_smith_observer.dart';
/// @docImport '/src/data/pagination/enums/fetch_trigger.dart';
/// @docImport '/src/data/refresh/models/reload.dart';
/// @docImport '/src/data/search/models/search_cache_policy.dart';
/// @docImport '/src/widgets/list_smith.dart';
library;

import 'package:meta/meta.dart';

import 'list_smith_controller_host.dart';

/// Drives a [ListSmith.async] list from code: a refresh button, a tab re-tap, a re-read after a local
/// write, a logout.
///
/// Intents only, never the pager or its state. Want to hear about events instead? That's [ListSmithObserver].
/// Holds nothing, so there's nothing to dispose.
class ListSmithController {
  ListSmithControllerHost? _host;
  var _wasEverAttached = false;

  /// Reloads exactly as a pull would, running the configured [Reload] ([ResetToFirstPage] when the list
  /// has no pull). While searching, it reloads the search.
  ///
  /// Completes when that reload does, which for [ResetToFirstPage] means as the list clears, not when
  /// fresh data lands. Joins a refresh already running. Asserts if no list ever attached.
  Future<void> refresh() {
    assert(
      _host != null || _wasEverAttached,
      'Pass this ListSmithController to ListSmith.async before calling refresh().',
    );

    return _host?.refresh() ?? Future<void>.syncValue(null);
  }

  /// Re-reads every loaded page in place, keeping the user's scroll position, because your data changed
  /// locally. Pages report [FetchTrigger.invalidated].
  ///
  /// Called during a running reload it joins that one and runs again after, so a write landing mid-read
  /// isn't missed.
  Future<void> invalidate() => _host?.invalidate() ?? Future<void>.syncValue(null);

  /// Starts the list over from page 0: a logout, an account switch, a filter outside search. That page
  /// reports [FetchTrigger.invalidated].
  ///
  /// Cuts in on a running reload rather than joining it. Keeps the query, so a search restarts, and
  /// a feed held by [KeepCachePolicy] starts over once the query clears.
  Future<void> reset() => _host?.reset() ?? Future<void>.syncValue(null);

  /// Binds this controller to the list it drives. One controller, one list.
  @internal
  void attach(ListSmithControllerHost host) {
    assert(_host == null, 'A ListSmithController drives one list; this one is already attached.');
    _host = host;
    _wasEverAttached = true;
  }

  /// Unbinds the list, leaving this controller inert. Called when that list is disposed.
  @internal
  void detach() => _host = null;
}

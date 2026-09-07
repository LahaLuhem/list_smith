/// @docImport '/src/data/observer/models/list_smith_observer.dart';
/// @docImport '/src/data/pagination/enums/fetch_trigger.dart';
/// @docImport '/src/data/refresh/models/reload.dart';
/// @docImport '/src/widgets/list_smith.dart';
library;

import 'package:meta/meta.dart';

import 'list_smith_controller_host.dart';

/// A narrow handle for driving a [ListSmith.async] list from code: a refresh button, a tab re-tap,
/// a re-read after a local write, a logout.
///
/// Intent-only by design: it never exposes the pager or its state. For lifecycle notifications use
/// a [ListSmithObserver] instead. Holds no resources, so there is nothing to dispose.
class ListSmithController {
  ListSmithControllerHost? _host;
  var _wasEverAttached = false;

  /// Reloads exactly as a pull would, running the configured [Reload] ([ResetToFirstPage] on a
  /// `NoRefresh` list) and reloading the current search while searching.
  ///
  /// Completes when that reload does: [ResetToFirstPage] as the list clears, not when fresh data
  /// lands, [ReloadToCurrentDepth] once the re-fetch is in. A call during a running refresh joins
  /// it, one during an [invalidate] runs once more after it. Inert once the list is gone, so racing
  /// a navigation is harmless. Calling it before any list attached asserts, since that is wiring
  /// rather than a race.
  Future<void> refresh() {
    assert(
      _host != null || _wasEverAttached,
      'Pass this ListSmithController to ListSmith.async before calling refresh().',
    );

    return _host?.refresh() ?? Future<void>.syncValue(null);
  }

  /// Re-reads every loaded page in place because what you handed the list changed locally, keeping
  /// the user's place whatever the pull is configured to do. Pages report [FetchTrigger.invalidated].
  ///
  /// A call during a running reload joins it and runs once more after, so a write landing mid-read
  /// is not missed. A no-op before any list attached: nothing loaded, nothing stale.
  Future<void> invalidate() => _host?.invalidate() ?? Future<void>.syncValue(null);

  /// Starts the list over from its first page, whatever the pull is configured to do: a logout, an
  /// account switch, a filter outside search. Page 0 reports [FetchTrigger.invalidated].
  ///
  /// Cuts in on a running reload rather than joining it. Keeps the query, so while searching the
  /// search restarts. A no-op before any list attached.
  Future<void> reset() => _host?.reset() ?? Future<void>.syncValue(null);

  /// Binds this controller to the list that serves its intents. One controller, one list.
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

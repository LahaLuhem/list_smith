/// @docImport '/src/data/observer/models/list_smith_observer.dart';
/// @docImport '/src/data/refresh/models/reload.dart';
/// @docImport '/src/widgets/list_smith.dart';
library;

import 'package:meta/meta.dart';

/// A narrow handle for driving a [ListSmith.async] list from code: a refresh button, a tab re-tap,
/// a reload after posting.
///
/// Intent-only by design: it never exposes the pager or its state. For lifecycle notifications use
/// a [ListSmithObserver] instead. Holds no resources, so there is nothing to dispose.
class ListSmithController {
  Future<void> Function()? _refresh;
  var _everAttached = false;

  /// Reloads exactly as a pull would, running the configured [Reload] ([ResetToFirstPage] on a
  /// `NoRefresh` list) and reloading the current search while searching.
  ///
  /// Completes when that reload does: [ResetToFirstPage] as the list clears, not when fresh data
  /// lands, [ReloadToCurrentDepth] once the re-fetch is in. A call during a running refresh joins
  /// it. Inert once the list is gone, so racing a navigation is harmless. Calling it before any list
  /// attached asserts, since that is wiring rather than a race.
  Future<void> refresh() {
    assert(
      _refresh != null || _everAttached,
      'Pass this ListSmithController to ListSmith.async before calling refresh().',
    );

    return _refresh?.call() ?? Future<void>.syncValue(null);
  }

  /// Binds this controller to the list that serves [refresh]. One controller, one list.
  @internal
  void attach(Future<void> Function() onRefresh) {
    assert(
      _refresh == null,
      'A ListSmithController drives one list; this one is already attached.',
    );
    _refresh = onRefresh;
    _everAttached = true;
  }

  /// Unbinds the list, leaving this controller inert. Called when that list is disposed.
  @internal
  void detach() => _refresh = null;
}

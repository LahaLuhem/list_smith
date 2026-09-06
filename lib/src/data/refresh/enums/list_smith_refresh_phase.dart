/// @docImport '../models/list_smith_refresh_state.dart';
library;

/// The phase of a pull-to-refresh gesture, as handed to a [RefreshBuilder].
///
/// Enough for a custom indicator to follow the pull without seeing the state machine underneath.
enum ListSmithRefreshPhase {
  /// At rest, no pull in progress. The indicator is normally hidden.
  idle,

  /// Being pulled, but not yet far enough to arm a refresh on release.
  dragging,

  /// Pulled past the threshold, so releasing now triggers a refresh.
  armed,

  /// A refresh is in flight: the fetch triggered by the release is running.
  refreshing,

  /// Animating back to rest, whether cancelled below the threshold or done after a refresh.
  settling,
}

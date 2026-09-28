/// @docImport '../models/list_smith_refresh_state.dart';
library;

/// The phase of a pull-to-refresh gesture, as handed to a [RefreshIndicatorBuilder].
///
/// Enough for a custom indicator to follow the pull without seeing the state machine underneath. There's
/// no resting phase, since nothing is built at rest.
enum ListSmithRefreshPhase {
  /// Being pulled, but not yet far enough to arm a refresh on release.
  dragging,

  /// Pulled past the threshold, so letting go now triggers a refresh.
  armed,

  /// A refresh is in flight.
  refreshing,

  /// Animating back to rest, whether cancelled below the threshold or done after a refresh.
  settling,
}

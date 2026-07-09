/// @docImport 'list_smith_refresh_state.dart';
library;

/// The phase of a pull-to-refresh gesture, as handed to a [RefreshBuilder].
///
/// A neutral view of the refresh lifecycle: enough for a custom indicator to
/// react to the pull, the arming, the in-flight refresh, and the return to
/// rest, without exposing the state machine list_smith drives internally.
enum ListSmithRefreshPhase {
  /// At rest; no pull in progress. The indicator is normally hidden.
  idle,

  /// Being pulled, but not yet far enough to arm a refresh on release.
  dragging,

  /// Pulled past the threshold; releasing now triggers a refresh.
  armed,

  /// A refresh is in flight: the fetch triggered by the release is running.
  refreshing,

  /// Animating back to rest, whether cancelled below the threshold or
  /// finishing after a refresh.
  settling,
}

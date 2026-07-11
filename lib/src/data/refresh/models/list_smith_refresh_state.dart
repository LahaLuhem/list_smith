import 'package:flutter/widgets.dart';

import '../enums/list_smith_refresh_phase.dart';

/// The state of list_smith's pull-to-refresh at build time, handed to a [RefreshBuilder].
///
/// A neutral wrapper over the refresh mechanism list_smith drives internally: it exposes only the
/// [phase] and drag [value] a custom indicator needs, so that mechanism (currently custom_refresh_indicator)
/// stays swappable without a breaking change to consumers.
@immutable
class ListSmithRefreshState {
  /// The current phase of the pull-to-refresh gesture.
  final ListSmithRefreshPhase phase;

  /// Pull progress: `0.0` at rest, `1.0` at the threshold that arms a refresh, and possibly greater
  /// than `1.0` while over-pulled.
  final double value;

  /// Creates a refresh state for the given [phase] and pull [value].
  const ListSmithRefreshState({required this.phase, required this.value});

  @override
  String toString() => 'ListSmithRefreshState(phase: $phase, value: $value)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListSmithRefreshState && other.phase == phase && other.value == value;

  @override
  int get hashCode => Object.hash(phase, value);
}

/// Draws a custom pull-to-refresh indicator around the scrollable `child`, using `state`.
///
/// Returns a widget that composes the indicator with `child`. `state` carries the phase and drag progress.
/// The underlying controller is never exposed, so a custom indicator reacts to the pull without
/// reaching into list_smith's internals.
typedef RefreshBuilder =
    Widget Function(BuildContext context, Widget child, ListSmithRefreshState state);

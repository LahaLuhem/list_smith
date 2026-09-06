import 'package:flutter/widgets.dart';

import '../enums/list_smith_refresh_phase.dart';

/// The state of list_smith's pull-to-refresh at build time, handed to a [RefreshBuilder].
///
/// Only the [phase] and drag [value] a custom indicator needs, so the mechanism underneath stays
/// swappable without a breaking change.
@immutable
class ListSmithRefreshState {
  /// The current phase of the pull-to-refresh gesture.
  final ListSmithRefreshPhase phase;

  /// Pull progress: `0.0` at rest, `1.0` at the threshold that arms a refresh, and possibly greater
  /// than `1.0` while over-pulled.
  final double value;

  /// Creates a refresh state for the given [phase] and pull [value].
  const new({required this.phase, required this.value});

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
/// Returns a widget composing the indicator with `child`. The controller underneath is never
/// exposed.
typedef RefreshBuilder = Widget Function(
  BuildContext context,
  Widget child,
  ListSmithRefreshState state,
);

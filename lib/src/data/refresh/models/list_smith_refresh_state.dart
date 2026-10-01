import 'package:flutter/widgets.dart';

import '../enums/list_smith_refresh_phase.dart';

/// The pull-to-refresh state at build time, handed to a [RefreshIndicatorBuilder].
///
/// Just the [phase], drag [value] and [pullDirection] a custom indicator needs, so the mechanism underneath
/// stays swappable.
@immutable
final class const ListSmithRefreshState({
  /// Where the gesture currently is.
  required final ListSmithRefreshPhase phase,

  /// Pull progress: `0.0` as the pull starts, `1.0` at the threshold that arms a refresh, more than `1.0`
  /// while over-pulled.
  required final double value,

  /// Which way the pull travels: `down` for a list pulled from its top, `up` when it's reversed.
  final AxisDirection pullDirection = .down,
}) {
  /// Creates it.
  this;

  @override
  String toString() =>
      'ListSmithRefreshState(phase: $phase, value: $value, pullDirection: $pullDirection)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListSmithRefreshState &&
          other.phase == phase &&
          other.value == value &&
          other.pullDirection == pullDirection;

  @override
  int get hashCode => Object.hash(phase, value, pullDirection);
}

/// Draws the pull indicator. Only called mid-pull, and list_smith decides where it sits.
typedef RefreshIndicatorBuilder = Widget Function(
  BuildContext context,
  ListSmithRefreshState state,
);

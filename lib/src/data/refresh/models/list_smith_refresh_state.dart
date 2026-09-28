import 'package:flutter/widgets.dart';

import '../enums/list_smith_refresh_phase.dart';

/// The pull-to-refresh state at build time, handed to a [RefreshIndicatorBuilder].
///
/// Just the [phase] and drag [value] a custom indicator needs, so the mechanism underneath stays swappable.
@immutable
class ListSmithRefreshState {
  /// Where the gesture currently is.
  final ListSmithRefreshPhase phase;

  /// Pull progress: `0.0` as the pull starts, `1.0` at the threshold that arms a refresh, more than `1.0`
  /// while over-pulled.
  final double value;

  /// Creates it.
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

/// Draws the pull indicator. Only called mid-pull, and list_smith decides where it sits.
typedef RefreshIndicatorBuilder = Widget Function(
  BuildContext context,
  ListSmithRefreshState state,
);

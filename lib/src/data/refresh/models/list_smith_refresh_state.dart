import 'package:flutter/widgets.dart';

import '../enums/list_smith_refresh_phase.dart';

/// The pull-to-refresh state at build time, handed to a [RefreshBuilder].
///
/// Just the [phase] and drag [value] a custom indicator needs, so the mechanism underneath stays swappable.
@immutable
class ListSmithRefreshState {
  /// Where the gesture currently is.
  final ListSmithRefreshPhase phase;

  /// Pull progress: `0.0` at rest, `1.0` at the threshold that arms a refresh, more than `1.0` while
  /// over-pulled.
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

/// Draws a custom pull-to-refresh indicator around the scrollable `child`, using `state`.
typedef RefreshBuilder = Widget Function(
  BuildContext context,
  Widget child,
  ListSmithRefreshState state,
);

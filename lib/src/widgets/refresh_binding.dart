import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/widgets.dart';

import '../data/refresh/list_smith_refresh_phase.dart';
import '../data/refresh/list_smith_refresh_state.dart';
import 'defaults/neutral_refresh_indicator.dart';

/// Wires list_smith's pull-to-refresh onto the custom_refresh_indicator package, keeping that dependency fully encapsulated.
///
/// Wraps [child] in a [CustomRefreshIndicator], maps its [IndicatorController] onto our neutral
/// [ListSmithRefreshState], and hands that to [refreshBuilder] (or the [NeutralRefreshIndicator] default when none is given).
/// The controller type never leaks past this boundary, so the refresh mechanism stays swappable.
/// Whether to enable pull-to-refresh at all is the shell's call: it omits this wrapper when refresh is off.
class RefreshBinding extends StatelessWidget {
  /// The scrollable subtree that the pull-to-refresh gesture drives.
  final Widget child;

  /// Called when a pull crosses the threshold and is released, to run the refresh.
  /// Completes when the refresh is done.
  final Future<void> Function() onRefresh;

  /// Draws the indicator, or `null` to use the neutral default.
  final RefreshBuilder? refreshBuilder;

  /// Creates a pull-to-refresh binding around [child].
  const RefreshBinding({
    required this.child,
    required this.onRefresh,
    this.refreshBuilder,
    super.key,
  });

  @override
  Widget build(BuildContext context) => CustomRefreshIndicator(
    onRefresh: onRefresh,
    builder: (context, child, controller) {
      final state = _stateOf(controller);

      return switch (refreshBuilder) {
        final builder? => builder(context, child, state),
        null => NeutralRefreshIndicator(state: state, child: child),
      };
    },
    child: child,
  );

  static ListSmithRefreshState _stateOf(IndicatorController controller) =>
      ListSmithRefreshState(phase: _phaseOf(controller.state), value: controller.value);

  static ListSmithRefreshPhase _phaseOf(IndicatorState state) => switch (state) {
    .idle => .idle,
    .dragging => .dragging,
    .armed => .armed,
    .loading => .refreshing,
    .settling || .canceling || .complete || .finalizing => .settling,
  };
}

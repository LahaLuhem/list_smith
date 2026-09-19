import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/widgets.dart';

import '/src/data/refresh/enums/list_smith_refresh_phase.dart';
import '/src/data/refresh/models/list_smith_refresh_state.dart';
import 'defaults/neutral_refresh_indicator.dart';

/// Wires pull-to-refresh onto custom_refresh_indicator, keeping that dependency out of sight.
///
/// Maps the [IndicatorController] onto our own [ListSmithRefreshState] and hands that to [refreshBuilder],
/// or to [NeutralRefreshIndicator]. The controller type never leaks past here, so the mechanism stays
/// swappable. Whether refresh happens at all is the engine's call: it leaves this wrapper out when refresh
/// is off.
class RefreshBinding extends StatelessWidget {
  /// The scrollable the gesture drives.
  final Widget child;

  /// Runs when a pull crosses the threshold and is let go. Completes when the refresh is done.
  final Future<void> Function() onRefresh;

  /// Draws the indicator, or `null` to use the neutral default.
  final RefreshBuilder? refreshBuilder;

  /// Creates it.
  const new({required this.child, required this.onRefresh, this.refreshBuilder, super.key});

  @override
  Widget build(BuildContext context) => CustomRefreshIndicator(
    onRefresh: onRefresh,
    child: child,
    builder: (context, child, controller) {
      final state = _stateOf(controller);

      return switch (refreshBuilder) {
        final builder? => builder(context, child, state),
        null => NeutralRefreshIndicator(state: state, child: child),
      };
    },
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

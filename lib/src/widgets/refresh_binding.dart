import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '/src/data/refresh/enums/list_smith_refresh_phase.dart';
import '/src/data/refresh/models/list_smith_refresh_state.dart';
import 'defaults/neutral_refresh_indicator.dart';

/// Wires pull-to-refresh onto custom_refresh_indicator, keeping that dependency out of sight.
///
/// Decides when the indicator exists and where it sits, so [indicatorBuilder] or [NeutralRefreshIndicator]
/// only draws it. The controller type never leaks past here, so the mechanism stays swappable. Whether
/// refresh happens at all is the engine's call: it leaves this wrapper out when refresh is off.
class RefreshBinding extends StatelessWidget {
  static const double _revealExtent = 64;

  /// The scrollable the gesture drives.
  final Widget child;

  /// Runs when a pull crosses the threshold and is let go. Completes when the refresh is done.
  final Future<void> Function() onRefresh;

  /// Draws the indicator, or `null` to use the neutral default.
  final RefreshIndicatorBuilder? indicatorBuilder;

  /// Creates it.
  const new({required this.child, required this.onRefresh, this.indicatorBuilder, super.key});

  @override
  Widget build(BuildContext context) => CustomRefreshIndicator(
    onRefresh: onRefresh,
    child: child,
    builder: (context, child, controller) {
      final state = _stateOf(controller);
      final revealedExtent = clampDouble(controller.value, 0, 1) * _revealExtent;

      return Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: _revealExtent,
            // Built only mid-pull, so no indicator can keep ticking while the list sits idle.
            child: state == null
                ? const SizedBox.shrink()
                : indicatorBuilder?.call(context, state) ?? NeutralRefreshIndicator(state: state),
          ),
          Transform.translate(offset: Offset(0, revealedExtent), child: child),
        ],
      );
    },
  );

  static ListSmithRefreshState? _stateOf(IndicatorController controller) {
    final phase = _phaseOf(controller.state);

    return phase == null ? null : ListSmithRefreshState(phase: phase, value: controller.value);
  }

  static ListSmithRefreshPhase? _phaseOf(IndicatorState state) => switch (state) {
    .idle => null,
    .dragging => .dragging,
    .armed => .armed,
    .loading => .refreshing,
    .settling || .canceling || .complete || .finalizing => .settling,
  };
}

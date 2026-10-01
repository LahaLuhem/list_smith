import 'dart:math' as math;

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
class const RefreshBinding({
  /// The scrollable the gesture drives.
  required final Widget child,

  /// Runs when a pull crosses the threshold and is let go. Completes when the refresh is done.
  required final Future<void> Function() onRefresh,

  /// The room the indicator gets along the scroll axis.
  required final double indicatorExtent,

  /// Draws the indicator, or `null` to use the neutral default.
  final RefreshIndicatorBuilder? indicatorBuilder,
  super.key,
}) extends StatefulWidget {
  /// Creates it.
  this;

  @override
  State<RefreshBinding> createState() => _RefreshBindingState();
}

class _RefreshBindingState() extends State<RefreshBinding> {
  /// How far the list has overshot its start on its own, which only bouncing physics allow.
  final _bounceDistanceNotifier = ValueNotifier<double>(0);

  @override
  void dispose() {
    _bounceDistanceNotifier.dispose();

    super.dispose();
  }

  bool _trackBounce(ScrollUpdateNotification notification) {
    final metrics = notification.metrics;
    _bounceDistanceNotifier.value = math.max(0, metrics.minScrollExtent - metrics.pixels);

    // Keeps bubbling, since custom_refresh_indicator reads the same notifications further up.
    return false;
  }

  @override
  Widget build(BuildContext context) => CustomRefreshIndicator(
    onRefresh: widget.onRefresh,
    child: NotificationListener(onNotification: _trackBounce, child: widget.child),
    builder: (context, child, controller) {
      final state = _stateOf(controller);
      // A pull always starts at the list's start, so its direction also says which edge it came from.
      final pullDirection = controller.direction;
      final isVertical = axisDirectionToAxis(pullDirection) == .vertical;
      final revealedExtent = clampDouble(controller.value, 0, 1) * widget.indicatorExtent;

      return Stack(
        children: [
          Positioned(
            top: pullDirection == .up ? null : 0,
            bottom: pullDirection == .down ? null : 0,
            left: pullDirection == .left ? null : 0,
            right: pullDirection == .right ? null : 0,
            width: isVertical ? null : widget.indicatorExtent,
            height: isVertical ? widget.indicatorExtent : null,
            // Built only mid-pull, so no indicator can keep ticking while the list sits idle.
            child: state == null
                ? const SizedBox.shrink()
                : widget.indicatorBuilder?.call(context, state) ??
                      NeutralRefreshIndicator(state: state),
          ),
          ValueListenableBuilder(
            valueListenable: _bounceDistanceNotifier,
            // Only the gap the list's own bounce hasn't opened, so bouncing physics aren't pushed twice.
            builder: (_, bounceDistance, _) {
              final distance = math.max<double>(0, revealedExtent - bounceDistance);
              final signedDistance = axisDirectionIsReversed(pullDirection) ? -distance : distance;

              return Transform.translate(
                offset: isVertical ? Offset(0, signedDistance) : Offset(signedDistance, 0),
                child: child,
              );
            },
          ),
        ],
      );
    },
  );

  static ListSmithRefreshState? _stateOf(IndicatorController controller) {
    final refreshPhase = _refreshPhaseOf(controller.state);

    return refreshPhase == null
        ? null
        : ListSmithRefreshState(
            phase: refreshPhase,
            value: controller.value,
            pullDirection: controller.direction,
          );
  }

  static ListSmithRefreshPhase? _refreshPhaseOf(IndicatorState state) => switch (state) {
    .idle => null,
    .dragging => .dragging,
    .armed => .armed,
    .loading => .refreshing,
    .settling || .canceling || .complete || .finalizing => .settling,
  };
}

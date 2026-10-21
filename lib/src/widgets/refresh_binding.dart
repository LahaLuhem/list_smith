import 'dart:math' as math;

import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '/src/data/refresh/refresh.dart';
import 'defaults/defaults.dart';

/// Wires pull-to-refresh onto custom_refresh_indicator, keeping that dependency out of sight.
///
/// Decides when the indicator exists and where it sits, so [indicatorBuilder] or [NeutralRefreshIndicator]
/// only draws it. The controller type never leaks past here, so the mechanism stays swappable. Whether
/// refresh happens at all is the engine's call: it leaves this wrapper out when refresh is off.
@internal
class const RefreshBinding({
  /// The scrollable the gesture drives.
  required final Widget child,

  /// Runs when a pull crosses the threshold and is let go. Completes when the refresh is done.
  required final AsyncCallback onRefresh,

  /// The room the indicator gets along the scroll axis.
  required final double indicatorExtent,

  /// Whether a pull may start on what the list shows now, asked as each drag starts.
  required final ValueGetter<bool> takesPullGetter,

  /// Set to how far the list is pushed now, so its rows can hold still as that changes.
  required final ValueNotifier<double> pullExtentNotifier,

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
  final _indicatorController = IndicatorController();

  /// How far the list has overshot its start on its own, which only bouncing physics allow.
  var _bounceDistance = 0.0;

  @override
  void initState() {
    super.initState();

    _indicatorController.addListener(_updatePullExtent);
  }

  @override
  void didUpdateWidget(RefreshBinding oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.indicatorExtent != oldWidget.indicatorExtent) _updatePullExtent();
  }

  @override
  void dispose() {
    _indicatorController
      ..removeListener(_updatePullExtent)
      ..dispose();

    super.dispose();
  }

  void _updatePullExtent() {
    final revealedExtent = clampDouble(_indicatorController.value, 0, 1) * widget.indicatorExtent;
    // Only the gap the list's own bounce hasn't opened, so bouncing physics aren't pushed twice.
    widget.pullExtentNotifier.value = math.max(0, revealedExtent - _bounceDistance);
  }

  bool _trackBounce(ScrollUpdateNotification notification) {
    final metrics = notification.metrics;
    _bounceDistance = math.max(0, metrics.minScrollExtent - metrics.pixels);
    _updatePullExtent();

    // Keeps bubbling, since custom_refresh_indicator reads the same notifications further up.
    return false;
  }

  /// Refuses only a drag's start where no pull is taken, so a pull the list changes under still sees
  /// its end and lets go.
  bool _isForIndicator(ScrollNotification notification) =>
      CustomRefreshIndicator.defaultScrollNotificationPredicate(notification) &&
      (notification is! ScrollStartNotification || widget.takesPullGetter());

  @override
  Widget build(BuildContext context) => CustomRefreshIndicator(
    controller: _indicatorController,
    onRefresh: widget.onRefresh,
    notificationPredicate: _isForIndicator,
    child: NotificationListener(onNotification: _trackBounce, child: widget.child),
    builder: (context, child, controller) {
      // A pull always starts at the list's start, so its direction also says which edge it came from.
      final pullDirection = controller.direction;
      final refreshState = controller.refreshState;
      final indicatorExtent = widget.indicatorExtent;
      // Built only mid-pull, so no indicator can keep ticking while the list sits idle.
      final indicatorWidget = refreshState == null
          ? const SizedBox.shrink()
          : widget.indicatorBuilder?.call(context, refreshState) ??
                NeutralRefreshIndicator(state: refreshState);
      final (edgeAlignment, indicatorSize, pushOffset) = switch (pullDirection) {
        .down => (Alignment.topCenter, Size.fromHeight(indicatorExtent), const Offset(0, 1)),
        .up => (Alignment.bottomCenter, Size.fromHeight(indicatorExtent), const Offset(0, -1)),
        .right => (Alignment.centerLeft, Size.fromWidth(indicatorExtent), const Offset(1, 0)),
        .left => (Alignment.centerRight, Size.fromWidth(indicatorExtent), const Offset(-1, 0)),
      };

      return Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: edgeAlignment,
              child: SizedBox.fromSize(size: indicatorSize, child: indicatorWidget),
            ),
          ),
          ValueListenableBuilder(
            valueListenable: widget.pullExtentNotifier,
            builder: (_, pullExtent, _) =>
                Transform.translate(offset: pushOffset * pullExtent, child: child),
          ),
        ],
      );
    },
  );
}

extension on IndicatorController {
  /// The indicator's state in list_smith's words, null while idle.
  ListSmithRefreshState? get refreshState {
    final refreshPhase = switch (state) {
      .idle => null,
      .dragging => ListSmithRefreshPhase.dragging,
      .armed => ListSmithRefreshPhase.armed,
      .loading => ListSmithRefreshPhase.refreshing,
      .settling || .canceling || .complete || .finalizing => ListSmithRefreshPhase.settling,
    };

    return refreshPhase == null
        ? null
        : ListSmithRefreshState(phase: refreshPhase, value: value, pullDirection: direction);
  }
}

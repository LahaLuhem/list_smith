import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/widgets.dart';
import 'package:list_smith/list_smith.dart';
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';
import 'package:platform_icons/platform_icons.dart' show PlatformIcon, PlatformIcons;

/// A platform-adaptive pull indicator: an arrow while pulling, a spinner while refreshing.
class CustomRefresh extends StatelessWidget {
  final ListSmithRefreshState state;

  const new({required this.state, super.key});

  @override
  Widget build(BuildContext context) {
    final indicator = switch (state.phase) {
      .refreshing || .settling => const PlatformProgressIndicator(),
      .dragging => _Arrow(pointing: state.pullDirection),
      .armed => _Arrow(pointing: flipAxisDirection(state.pullDirection)),
    };

    return Opacity(
      opacity: clampDouble(state.value, 0, 1),
      child: Center(child: indicator),
    );
  }
}

/// One glyph turned to point any way, since a left or right arrow icon gets mirrored under RTL.
class _Arrow extends StatelessWidget {
  final AxisDirection pointing;

  const new({required this.pointing});

  @override
  Widget build(BuildContext context) => RotatedBox(
    quarterTurns: switch (pointing) {
      .down => 0,
      .left => 1,
      .up => 2,
      .right => 3,
    },
    child: const PlatformIcon(PlatformIcons.arrowDown),
  );
}

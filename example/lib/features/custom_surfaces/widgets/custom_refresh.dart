import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/widgets.dart';
import 'package:list_smith/list_smith.dart';
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';
import 'package:platform_icons/platform_icons.dart' show PlatformIcon, PlatformIcons;

class const CustomRefresh({required final ListSmithRefreshState state, super.key})
    extends StatelessWidget {
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
class const _Arrow({required final AxisDirection pointing}) extends StatelessWidget {
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

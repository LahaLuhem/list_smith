import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/widgets.dart';
import 'package:list_smith/list_smith.dart';
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';
import 'package:platform_icons/platform_icons.dart' show PlatformIcon, PlatformIcons;

/// A custom pull-to-refresh indicator, overriding the neutral default. Reveals
/// from the top keyed to [ListSmithRefreshState.value] (translating the list
/// down), showing a directional arrow while pulling and a spinner while
/// refreshing.
class CustomRefresh extends StatelessWidget {
  static const double _extent = 72;

  final Widget child;
  final ListSmithRefreshState state;

  const CustomRefresh({required this.child, required this.state, super.key});

  @override
  Widget build(BuildContext context) {
    final progress = clampDouble(state.value, 0, 1);
    final revealed = progress * _extent;
    final indicator = switch (state.phase) {
      .refreshing || .settling => const PlatformProgressIndicator(),
      .armed => const PlatformIcon(PlatformIcons.arrowUp),
      .idle || .dragging => const PlatformIcon(PlatformIcons.arrowDown),
    };

    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: _extent,
          child: Opacity(
            opacity: progress,
            child: Center(child: indicator),
          ),
        ),
        Transform.translate(offset: Offset(0, revealed), child: child),
      ],
    );
  }
}

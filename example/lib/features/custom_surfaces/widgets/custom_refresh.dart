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
      .armed => const PlatformIcon(PlatformIcons.arrowUp),
      .dragging => const PlatformIcon(PlatformIcons.arrowDown),
    };

    return Opacity(
      opacity: clampDouble(state.value, 0, 1),
      child: Center(child: indicator),
    );
  }
}

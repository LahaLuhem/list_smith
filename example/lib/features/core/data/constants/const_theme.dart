import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoThemeData;
import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/widgets.dart'
    show Brightness, BuildContext, Center, Color, Opacity, Padding, SizeTransition, Widget;
import 'package:list_smith/list_smith.dart'
    show AsyncListSurfaces, EditTransition, ListSmithRefreshState;
import 'package:material_ui/material_ui.dart' show ColorScheme, ThemeData;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart'
    show PlatformProgressIndicator;

/// One seed colour drives a Material 3 light and dark scheme plus a matching Cupertino theme.
abstract final class ConstTheme._() {
  static const seedColor = Color(0xFF4F46E5);

  static final materialLight = ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: seedColor));

  static final materialDark = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark),
  );

  static final sizeEditTransition = EditTransition(
    duration: const Duration(milliseconds: 250),
    transitionBuilder: (child, animation) => SizeTransition(sizeFactor: animation, child: child),
  );

  static final platformSurfaces = AsyncListSurfaces(
    firstPageLoadingBuilder: (_) => const Center(child: PlatformProgressIndicator()),
    newPageLoadingBuilder: (_) => const Padding(
      padding: .all(16),
      child: Center(child: PlatformProgressIndicator()),
    ),
  );

  static Widget platformRefreshIndicator(BuildContext _, ListSmithRefreshState state) => Opacity(
    opacity: clampDouble(state.value, 0, 1),
    child: const Center(child: PlatformProgressIndicator()),
  );

  /// A `null` [brightness] follows the device.
  static CupertinoThemeData cupertino(Brightness? brightness) =>
      CupertinoThemeData(brightness: brightness, primaryColor: seedColor);
}

import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoThemeData;
import 'package:flutter/widgets.dart' show Brightness, Color, SizeTransition;
import 'package:list_smith/list_smith.dart' show EditTransition;
import 'package:material_ui/material_ui.dart' show ColorScheme, ThemeData;

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

  /// A `null` [brightness] follows the device.
  static CupertinoThemeData cupertino(Brightness? brightness) =>
      CupertinoThemeData(brightness: brightness, primaryColor: seedColor);
}

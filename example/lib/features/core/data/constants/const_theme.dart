import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoThemeData;
import 'package:flutter/widgets.dart' show Brightness, Color;
import 'package:material_ui/material_ui.dart' show ColorScheme, ThemeData;

/// One seed colour drives a Material 3 light and dark scheme plus a matching Cupertino theme.
abstract final class ConstTheme {
  static const seedColor = Color(0xFF4F46E5);

  static final materialLight = ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: seedColor));

  static final materialDark = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark),
  );

  /// A `null` [brightness] follows the device.
  static CupertinoThemeData cupertino(Brightness? brightness) =>
      CupertinoThemeData(brightness: brightness, primaryColor: seedColor);
}

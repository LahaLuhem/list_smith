import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoThemeData;
import 'package:flutter/widgets.dart' show Brightness, Color;
import 'package:material_ui/material_ui.dart' show ColorScheme, ThemeData;

/// Branded theming for the demo. One seed colour drives a Material 3 light/dark
/// scheme and a matching Cupertino theme, so the app looks designed on both
/// platforms and the appearance toggle has something to switch between.
abstract final class ConstTheme {
  /// The brand seed. Everything else is derived from it.
  static const seedColor = Color(0xFF4F46E5);

  static final materialLight = ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: seedColor));

  static final materialDark = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark),
  );

  /// Cupertino theme for the given [brightness]. Pass `null` to follow the
  /// device (used when the app's theme mode is `system`).
  static CupertinoThemeData cupertino(Brightness? brightness) =>
      CupertinoThemeData(brightness: brightness, primaryColor: seedColor);
}

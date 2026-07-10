import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Icons, ThemeMode;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';

import '/app/theme_scope.dart';

/// The shell every demo screen sits in: a [PlatformScaffold] with [title] and a
/// brightness toggle in the app bar, so the neutral list surfaces can be seen in
/// light and dark from any screen.
class DemoScaffold extends StatelessWidget {
  final String title;
  final Widget body;

  const DemoScaffold({required this.title, required this.body, super.key});

  @override
  Widget build(BuildContext context) => PlatformScaffold(
    appBarData: PlatformAppBar(
      title: Text(title),
      materialAppBarData: const MaterialAppBarData(actions: [_BrightnessToggle()]),
      cupertinoNavigationBarData: const CupertinoNavigationBarData(trailing: _BrightnessToggle()),
    ),
    body: SafeArea(child: body),
  );
}

/// Cycles the app-wide theme mode (system -> light -> dark) from the app bar.
class _BrightnessToggle extends StatelessWidget {
  const _BrightnessToggle();

  @override
  Widget build(BuildContext context) {
    final themeMode = ThemeScope.of(context);

    return GestureDetector(
      onTap: () => themeMode.value = _nextThemeMode(themeMode.value),
      behavior: .opaque,
      child: Padding(
        padding: const .all(12),
        child: Icon(_brightnessIcon(themeMode.value), size: 22),
      ),
    );
  }
}

// Brightness glyphs aren't in platform_icons, so these fall back to
// platformValue (per the example's icon convention).
IconData _brightnessIcon(ThemeMode mode) => switch (mode) {
  .system => platformValue(
    material: Icons.brightness_auto,
    cupertino: CupertinoIcons.circle_lefthalf_fill,
  ),
  .light => platformValue(material: Icons.light_mode, cupertino: CupertinoIcons.sun_max),
  .dark => platformValue(material: Icons.dark_mode, cupertino: CupertinoIcons.moon_fill),
};

ThemeMode _nextThemeMode(ThemeMode mode) => switch (mode) {
  .system => .light,
  .light => .dark,
  .dark => .system,
};

import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Icons, ThemeMode;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';

import '/app/theme_scope.dart';

/// Every demo's shell. Its brightness toggle shows the neutral surfaces light and dark from any screen.
class DemoScaffold extends StatelessWidget {
  final String title;
  final Widget body;

  const new({required this.title, required this.body, super.key});

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

class _BrightnessToggle extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final themeModeNotifier = ThemeScope.of(context);

    return GestureDetector(
      onTap: () => themeModeNotifier.value = _nextThemeMode(themeModeNotifier.value),
      behavior: .opaque,
      child: Padding(
        padding: const .all(12),
        child: Icon(_brightnessIcon(themeModeNotifier.value), size: 22),
      ),
    );
  }
}

// No brightness glyphs in platform_icons, so fall back to platformValue.
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

import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show ThemeMode;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';

import 'app/theme_scope.dart';
import 'features/core/data/constants/const_theme.dart';
import 'features/core/views/home_view.dart';

void main() => runApp(const ListSmithExampleApp());

/// Showcase app for `list_smith`, built on the sibling packages' platform-adaptive
/// stack so the neutral list surfaces can be seen dropping into a Material shell
/// (Android) and a Cupertino shell (iOS) unchanged.
///
/// Owns the app-wide theme mode and publishes it through [ThemeScope], so any
/// screen can flip brightness live (see the app-bar control in `DemoScaffold`).
/// Platform follows the real device.
class ListSmithExampleApp extends StatefulWidget {
  const ListSmithExampleApp({super.key});

  @override
  State<ListSmithExampleApp> createState() => _ListSmithExampleAppState();
}

class _ListSmithExampleAppState extends State<ListSmithExampleApp> {
  final _themeMode = ValueNotifier(ThemeMode.system);

  @override
  void dispose() {
    _themeMode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: _themeMode,
    builder: (context, themeMode, _) => PlatformApp(
      title: 'list_smith example',
      debugShowCheckedModeBanner: false,
      materialAppData: MaterialAppData(
        theme: ConstTheme.materialLight,
        darkTheme: ConstTheme.materialDark,
        themeMode: themeMode,
      ),
      cupertinoAppData: CupertinoAppData(
        theme: ConstTheme.cupertino(_cupertinoBrightness(themeMode)),
      ),
      builder: (_, child) => ThemeScope(notifier: _themeMode, child: child!),
      home: const HomeView(),
    ),
  );

  /// Cupertino has no `themeMode`; map it to an explicit brightness, or `null`
  /// to follow the device (the `system` case).
  Brightness? _cupertinoBrightness(ThemeMode mode) => switch (mode) {
    .system => null,
    .light => Brightness.light,
    .dark => Brightness.dark,
  };
}

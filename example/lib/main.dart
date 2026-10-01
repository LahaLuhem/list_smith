import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show ThemeMode;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';

import 'app/theme_scope.dart';
import 'features/core/data/constants/const_theme.dart';
import 'features/core/views/home_view.dart';

void main() => runApp(const ListSmithExampleApp());

class ListSmithExampleApp extends StatefulWidget {
  const new({super.key});

  @override
  State<ListSmithExampleApp> createState() => _ListSmithExampleAppState();
}

class _ListSmithExampleAppState extends State<ListSmithExampleApp> {
  final _themeModeNotifier = ValueNotifier(ThemeMode.system);

  @override
  void dispose() {
    _themeModeNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: _themeModeNotifier,
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
      builder: (_, child) => ThemeScope(notifier: _themeModeNotifier, child: child!),
      home: const HomeView(),
    ),
  );

  /// Cupertino has no `themeMode`, so map it to a brightness, or `null` to follow the device.
  Brightness? _cupertinoBrightness(ThemeMode mode) => switch (mode) {
    .system => null,
    .light => Brightness.light,
    .dark => Brightness.dark,
  };
}

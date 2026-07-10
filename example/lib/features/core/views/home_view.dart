import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Icons, MaterialPageRoute, Navigator;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';
import 'package:platform_icons/platform_icons.dart' show PlatformIcon, PlatformIcons;
import 'package:pmvvm/mvvm_builder.widget.dart';

import '/features/basic_feed/basic_feed_view.dart';
import '/features/custom_surfaces/custom_surfaces_view.dart';
import '/features/playground/playground_view.dart';
import '../widgets/demo_scaffold.dart';
import 'home_view_model.dart';

/// The landing hub: a tappable list of the individual `list_smith` demos.
class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) => MVVM.builder(
    viewModel: HomeViewModel(),
    viewBuilder: (context, _) => DemoScaffold(
      title: 'list_smith',
      body: ListView(
        padding: const .symmetric(vertical: 8),
        children: [
          _DemoTile(
            icon: const PlatformIcon(PlatformIcons.grid),
            title: 'Basic feed',
            description: 'Async pagination and pull-to-refresh with the neutral default surfaces.',
            pageBuilder: (_) => const BasicFeedView(),
          ),
          _DemoTile(
            icon: const PlatformIcon(PlatformIcons.wand),
            title: 'Custom surfaces',
            description: 'Replace every neutral surface (loading, error, empty, end, refresh).',
            pageBuilder: (_) => const CustomSurfacesView(),
          ),
          _DemoTile(
            icon: const PlatformIcon(PlatformIcons.slider),
            title: 'Playground',
            description: 'Tweak page size, end policy, latency, refresh, and separators live.',
            pageBuilder: (_) => const PlaygroundView(),
          ),
        ],
      ),
    ),
  );
}

/// One row in the hub: a platform list tile that pushes a demo screen.
class _DemoTile extends StatelessWidget {
  final Widget icon;
  final String title;
  final String description;
  final WidgetBuilder pageBuilder;

  const _DemoTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.pageBuilder,
  });

  @override
  Widget build(BuildContext context) => PlatformListTile(
    leading: icon,
    title: Text(title),
    subtitle: Text(description),
    // No chevron glyph in platform_icons, so fall back to platformValue.
    trailing: Icon(
      platformValue(material: Icons.chevron_right, cupertino: CupertinoIcons.right_chevron),
    ),
    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: pageBuilder)),
  );
}

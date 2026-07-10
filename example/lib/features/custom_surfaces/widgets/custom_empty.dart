import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Icons;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';

/// A platform-adaptive empty surface, shown when the source has no items at all.
class CustomEmpty extends StatelessWidget {
  const CustomEmpty({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: .min,
      spacing: 12,
      children: [
        // No tray glyph in platform_icons, so fall back to platformValue.
        Icon(platformValue(material: Icons.inbox, cupertino: CupertinoIcons.tray), size: 40),
        const Text('Nothing here yet'),
      ],
    ),
  );
}

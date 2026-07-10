import 'package:flutter/widgets.dart';
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';

/// A platform-adaptive loading surface, overriding the neutral default. [compact]
/// switches between the full-viewport first-page form and the new-page footer.
class CustomLoading extends StatelessWidget {
  final bool compact;

  const CustomLoading({this.compact = false, super.key});

  @override
  Widget build(BuildContext context) => compact
      ? const Padding(
          padding: .all(16),
          child: Row(
            mainAxisAlignment: .center,
            spacing: 12,
            children: [
              SizedBox.square(dimension: 18, child: PlatformProgressIndicator()),
              Text('Loading more…'),
            ],
          ),
        )
      : const Center(
          child: Column(
            mainAxisSize: .min,
            spacing: 12,
            children: [PlatformProgressIndicator(), Text('Loading…')],
          ),
        );
}

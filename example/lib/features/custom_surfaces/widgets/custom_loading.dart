import 'package:flutter/widgets.dart';
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';

/// [isCompact] picks the new-page footer over the full-viewport first-page form.
class CustomLoading extends StatelessWidget {
  final bool isCompact;

  const new({this.isCompact = false, super.key});

  @override
  Widget build(BuildContext context) => isCompact
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

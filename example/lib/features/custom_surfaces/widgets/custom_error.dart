import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Icons;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';
import 'package:platform_icons/platform_icons.dart' show PlatformIcon, PlatformIcons;

/// A platform-adaptive error surface carrying the error and a retry action.
/// [compact] switches between the full-viewport first-page form and the
/// new-page footer form.
class CustomError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  final bool compact;

  const CustomError({required this.error, required this.onRetry, this.compact = false, super.key});

  @override
  Widget build(BuildContext context) => compact
      ? Padding(
          padding: const .all(12),
          child: Row(
            children: [
              const Expanded(child: Text('Could not load more.')),
              PlatformButton(
                onPressed: onRetry,
                materialButtonVariant: .text,
                child: const Text('Retry'),
              ),
            ],
          ),
        )
      : Center(
          child: Padding(
            padding: const .all(16),
            child: Column(
              mainAxisSize: .min,
              spacing: 12,
              children: [
                // No error glyph in platform_icons, so fall back to platformValue.
                Icon(
                  platformValue(
                    material: Icons.error_outline,
                    cupertino: CupertinoIcons.exclamationmark_circle,
                  ),
                  size: 40,
                ),
                const Text('Something went wrong', style: TextStyle(fontWeight: .w600)),
                Text(error.toString(), textAlign: .center, maxLines: 3, overflow: .ellipsis),
                PlatformButton.icon(
                  onPressed: onRetry,
                  icon: const PlatformIcon(PlatformIcons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
}

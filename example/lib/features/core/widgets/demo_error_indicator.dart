import 'package:flutter/widgets.dart';
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';

/// The neutral error layout, retrying through a [PlatformButton]. [isCompact] picks the new-page
/// footer over the full-viewport first-page form.
class const DemoErrorIndicator({
  required final Exception exception,
  required final VoidCallback onRetry,
  final bool isCompact = false,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: .all(isCompact ? 12 : 16),
    child: Center(
      child: Column(
        mainAxisSize: .min,
        spacing: isCompact ? 8 : 12,
        children: [
          if (!isCompact) const Text('Something went wrong'),
          Text(exception.toString(), textAlign: .center, maxLines: 3, overflow: .ellipsis),
          PlatformButton(onPressed: onRetry, emphasis: .medium, child: const Text('Retry')),
        ],
      ),
    ),
  );
}

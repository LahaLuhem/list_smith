import 'package:flutter/widgets.dart';

import '/src/utils/neutral_theme.dart';
import 'neutral_retry_button.dart';

/// The neutral surface for a page that failed to load.
///
/// A heading, the error's own description, and a [NeutralRetryButton]. Full-viewport for the 1st page,
/// or pass [isCompact] for the tighter footer used when a later page fails below the items already loaded.
class NeutralErrorIndicator extends StatelessWidget {
  static const double _spacing = 12;
  static const double _padding = 16;
  static const double _compactSpacing = 8;
  static const double _compactPadding = 12;
  static const _errorMaxLines = 3;

  /// What the load failed with.
  final Object error;

  /// Re-attempts the failed load.
  final VoidCallback onRetry;

  /// Render the tighter footer form rather than the full-viewport one.
  final bool isCompact;

  /// Creates it.
  const new({required this.error, required this.onRetry, this.isCompact = false, super.key});

  @override
  Widget build(BuildContext context) {
    final foregroundColour = neutralForegroundOf(context);

    return Padding(
      padding: .all(isCompact ? _compactPadding : _padding),
      child: Center(
        child: Column(
          mainAxisSize: .min,
          spacing: isCompact ? _compactSpacing : _spacing,
          children: [
            if (!isCompact) const Text('Something went wrong'),
            Text(
              error.toString(),
              textAlign: .center,
              maxLines: _errorMaxLines,
              overflow: .ellipsis,
              style: TextStyle(color: foregroundColour),
            ),
            NeutralRetryButton(onRetry: onRetry),
          ],
        ),
      ),
    );
  }
}

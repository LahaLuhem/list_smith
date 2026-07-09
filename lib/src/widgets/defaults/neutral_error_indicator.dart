import 'package:flutter/widgets.dart';

import '../../utils/neutral_theme.dart';
import 'neutral_retry_button.dart';

/// The neutral default surface shown when a page fails to load.
///
/// Presents a short heading, the error's own description, and a [NeutralRetryButton] wired to re-attempt the load.
/// Full-viewport and centred for the first page; pass [compact] for the tighter footer form used when
/// a later page fails below already-loaded items. Carries the [error] and [onRetry] our public error-builder
/// contract exposes, so a replacement surface can offer retry without reaching into a hidden controller.
class NeutralErrorIndicator extends StatelessWidget {
  static const double _spacing = 12;
  static const double _padding = 16;
  static const double _compactSpacing = 8;
  static const double _compactPadding = 12;
  static const _errorMaxLines = 3;

  /// The error that caused the load to fail.
  final Object error;

  /// Invoked to re-attempt the failed load.
  final VoidCallback onRetry;

  /// Whether to render the tighter footer form (a later page failed) rather than the full-viewport form
  /// (the first page failed).
  final bool compact;

  /// Creates the neutral error surface for [error], wiring retry to [onRetry].
  const NeutralErrorIndicator({
    required this.error,
    required this.onRetry,
    this.compact = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final foregroundColour = neutralForegroundOf(context);

    return Padding(
      padding: .all(compact ? _compactPadding : _padding),
      child: Center(
        child: Column(
          mainAxisSize: .min,
          spacing: compact ? _compactSpacing : _spacing,
          children: [
            if (!compact) const Text('Something went wrong'),
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

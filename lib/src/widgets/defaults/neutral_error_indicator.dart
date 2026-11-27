import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import '/src/utils/neutral_theme.dart';
import 'neutral_retry_button.dart';

/// The neutral surface for a page that failed to load.
///
/// A heading, the error's own description, and a [NeutralRetryButton]. Full-viewport for the 1st page,
/// or [isCompact] beside the rows: a later page's footer, a failed reload's error.
@internal
class const NeutralErrorIndicator({
  /// What the load failed with.
  required final Exception exception,

  /// Re-attempts the failed load.
  required final VoidCallback onRetry,

  /// The tighter form, beside the rows.
  final bool isCompact = false,

  /// What failed. Null shows a generic one at full size, none when compact.
  final String? heading,
  super.key,
}) extends StatelessWidget {
  static const double _spacing = 12;
  static const double _padding = 16;
  static const double _compactSpacing = 8;
  static const double _compactPadding = 12;
  static const _errorMaxLines = 3;

  /// Creates it.
  this;

  @override
  Widget build(BuildContext context) {
    final foregroundColour = neutralForegroundOf(context);
    final headingText = heading ?? (isCompact ? null : 'Something went wrong');
    final indicatorPadding = Padding(
      padding: .all(isCompact ? _compactPadding : _padding),
      child: Center(
        child: Column(
          mainAxisSize: .min,
          spacing: isCompact ? _compactSpacing : _spacing,
          children: [
            if (headingText != null) Text(headingText),
            Text(
              exception.toString(),
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

    // Large text can outgrow the list.
    return isCompact
        ? indicatorPadding
        : LayoutBuilder(
            builder: (_, constraints) => SingleChildScrollView(
              // Else it grabs the app's primary controller.
              primary: false,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: indicatorPadding,
              ),
            ),
          );
  }
}

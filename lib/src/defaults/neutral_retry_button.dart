import 'package:flutter/widgets.dart';

import 'neutral_theme.dart';

/// A neutral, widgets-layer "retry" control for list_smith's error surfaces.
///
/// The widgets layer ships no button (buttons live in Material and Cupertino), so this hand-rolls a tappable,
/// outlined control that inherits the ambient foreground colour via [neutralForegroundOf].
/// Kept internal: consumers restyle by overriding the error builder wholesale, not this button.
class NeutralRetryButton extends StatelessWidget {
  static const _padding = EdgeInsets.symmetric(horizontal: 16, vertical: 8);
  static const _radius = BorderRadius.all(.circular(8));

  /// Invoked when the control is tapped, to re-attempt the failed load.
  final VoidCallback onRetry;

  /// Creates a retry control that calls [onRetry] when tapped.
  const NeutralRetryButton({required this.onRetry, super.key});

  @override
  Widget build(BuildContext context) {
    final foregroundColour = neutralForegroundOf(context);

    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onRetry,
        behavior: HitTestBehavior.opaque,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: .fromBorderSide(BorderSide(color: foregroundColour)),
            borderRadius: _radius,
          ),
          child: Padding(
            padding: _padding,
            child: Text('Retry', style: TextStyle(color: foregroundColour)),
          ),
        ),
      ),
    );
  }
}

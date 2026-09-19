import 'package:flutter/widgets.dart';

import '/src/utils/neutral_theme.dart';

/// A widgets-layer "retry" control for the error surfaces.
///
/// The widgets layer ships no button, so this hand-rolls one. Internal: restyling means overriding the
/// error builder wholesale, not this.
class NeutralRetryButton extends StatelessWidget {
  static const _padding = EdgeInsets.symmetric(horizontal: 16, vertical: 8);
  static const _radius = BorderRadius.all(.circular(8));

  /// Runs on tap, to re-attempt the failed load.
  final VoidCallback onRetry;

  /// Creates it.
  const new({required this.onRetry, super.key});

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

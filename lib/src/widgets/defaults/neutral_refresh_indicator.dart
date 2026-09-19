import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '/src/data/refresh/models/list_smith_refresh_state.dart';
import 'neutral_progress_indicator.dart';

/// The neutral pull-to-refresh indicator.
///
/// Reveals a [NeutralProgressIndicator] from the top as the pull progresses, keyed to [ListSmithRefreshState.value].
/// Override `refreshBuilder` to replace it.
class NeutralRefreshIndicator extends StatelessWidget {
  static const double _revealExtent = 64;

  /// The list, translated down to reveal the indicator.
  final Widget child;

  /// Drives the reveal.
  final ListSmithRefreshState state;

  /// Creates it.
  const new({required this.child, required this.state, super.key});

  @override
  Widget build(BuildContext context) {
    final progress = clampDouble(state.value, 0, 1);
    final revealedExtent = progress * _revealExtent;

    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: _revealExtent,
          child: Opacity(
            opacity: progress,
            child: const Center(child: NeutralProgressIndicator()),
          ),
        ),
        Transform.translate(offset: Offset(0, revealedExtent), child: child),
      ],
    );
  }
}

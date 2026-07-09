import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../data/refresh/list_smith_refresh_state.dart';
import 'neutral_progress_indicator.dart';

/// The neutral default pull-to-refresh indicator.
///
/// Reveals a [NeutralProgressIndicator] from the top of the list as the pull progresses
/// (keyed to [ListSmithRefreshState.value]) and keeps it spinning while a refresh runs.
/// Imposes no design system. Consumers override the refresh builder to replace it.
class NeutralRefreshIndicator extends StatelessWidget {
  static const double _revealExtent = 64;

  /// The list being refreshed, translated down to reveal the indicator.
  final Widget child;

  /// The pull-to-refresh state driving the reveal.
  final ListSmithRefreshState state;

  /// Creates the neutral refresh indicator around [child] for [state].
  const NeutralRefreshIndicator({required this.child, required this.state, super.key});

  @override
  Widget build(BuildContext context) {
    final progress = clampDouble(state.value, 0, 1);
    final revealed = progress * _revealExtent;

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
        Transform.translate(offset: Offset(0, revealed), child: child),
      ],
    );
  }
}

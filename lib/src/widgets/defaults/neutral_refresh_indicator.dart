import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '/src/data/refresh/models/list_smith_refresh_state.dart';
import 'neutral_progress_indicator.dart';

/// The neutral pull indicator. Override `indicatorBuilder` to replace it.
class NeutralRefreshIndicator extends StatelessWidget {
  /// The pull it follows.
  final ListSmithRefreshState state;

  /// Creates it.
  const new({required this.state, super.key});

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: clampDouble(state.value, 0, 1),
    child: const Center(child: NeutralProgressIndicator()),
  );
}

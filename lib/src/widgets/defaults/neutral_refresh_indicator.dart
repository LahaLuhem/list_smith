import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '/src/data/refresh/models/list_smith_refresh_state.dart';
import 'neutral_progress_indicator.dart';

/// The neutral pull indicator. Override `indicatorBuilder` to replace it.
class const NeutralRefreshIndicator({
  /// The pull it follows.
  required final ListSmithRefreshState state,
  super.key,
}) extends StatelessWidget {
  /// Creates it.
  this;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: clampDouble(state.value, 0, 1),
    child: const Center(child: NeutralProgressIndicator()),
  );
}

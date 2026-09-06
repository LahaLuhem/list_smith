/// @docImport '/src/widgets/list_smith.dart';
library;

import 'list_smith_refresh_state.dart';
import 'reload.dart';

part 'refreshes/no_refresh.dart';
part 'refreshes/pull_to_refresh.dart';

/// Whether an async list has pull-to-refresh, and how its indicator is drawn.
///
/// [PullToRefresh] (the default) is refresh on with the neutral indicator, [NoRefresh] is off. The
/// indicator rides the on-case, so it can't be set on a list that never refreshes.
/// [ListSmith.async] only: an in-memory list has nothing to refresh.
sealed class Refresh {
  /// Const base constructor.
  const new();
}

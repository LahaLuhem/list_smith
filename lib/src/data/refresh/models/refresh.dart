/// @docImport '/src/widgets/list_smith.dart';
library;

import 'list_smith_refresh_state.dart';

part 'refreshes/no_refresh.dart';
part 'refreshes/pull_to_refresh.dart';

/// Whether an async list has pull-to-refresh, and how its indicator is drawn.
///
/// A sealed, injected, defaulted seam, like the pagination end and search cache policies: the default
/// is [PullToRefresh] (refresh on, neutral indicator), switched off by passing [NoRefresh]. Applies to
/// [ListSmith.async] only, since an in-memory `.sync` list has nothing to refresh. Bundling the on/off
/// choice with the indicator means a refresh indicator can only be set on a list that actually
/// refreshes, so no builder is ever left inert on a non-refreshing list.
sealed class Refresh {
  /// Const base constructor for the sealed hierarchy.
  const Refresh();
}

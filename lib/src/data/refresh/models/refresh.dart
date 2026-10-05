/// @docImport '/src/widgets/list_smith.dart';
library;

import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import '/src/data/pagination/enums/paging_status.dart';
import '../enums/pullable_surface.dart';
import 'list_smith_refresh_state.dart';
import 'reload.dart';

part 'refreshes/no_refresh.dart';
part 'refreshes/pull_to_refresh.dart';

/// Whether an async list has pull-to-refresh, and how its indicator is drawn.
///
/// [PullToRefresh] (the default) is on, [NoRefresh] is off. The indicator rides the on-case, so it can't
/// be set on a list that never refreshes. [ListSmith.async] only.
sealed class const Refresh() {
  /// Const base constructor.
  this;

  /// The same on every surface, since swapping physics mid-drag cancels the drag.
  @internal
  ScrollPhysics? scrollPhysics(ScrollPhysics? physics);

  /// Whether a pull may start while the list shows [status].
  @internal
  bool takesPull(PagingStatus status);
}

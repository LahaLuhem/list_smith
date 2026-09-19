/// @docImport '/src/data/presentation/models/async_list_surfaces.dart';
/// @docImport '/src/widgets/list_smith.dart';
/// @docImport 'pagination_end_policy.dart';
library;

import 'empty_page_context.dart';

part 'empty_page_behaviours/advance_to_first_non_empty.dart';
part 'empty_page_behaviours/show_empty_surface.dart';

/// What an async list does when a page comes back empty but [PaginationEndPolicy] says more pages remain.
/// Nothing on screen means nothing to scroll, so the list would otherwise sit there stuck.
///
/// [ShowEmptySurface] (the default) shows the empty surface. [AdvanceToFirstNonEmpty] pages on to the
/// 1st page with items, which only matters under a policy that continues past an empty page: a raised
/// [StopOnEmptyPagesPolicy.emptyRunBeforeEnd] or a signal policy. [ListSmith.async] only.
sealed class EmptyPageBehaviour {
  /// Const base constructor.
  const new();

  /// Whether to page past the current empty page. Called after each page lands.
  bool shouldAdvance(EmptyPageContext context);
}

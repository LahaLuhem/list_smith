/// @docImport '/src/data/presentation/models/async_list_surfaces.dart';
/// @docImport '/src/data/refresh/models/refresh.dart';
/// @docImport '/src/widgets/list_smith.dart';
/// @docImport 'pagination_end_policy.dart';
library;

import 'empty_page_context.dart';

part 'empty_page_behaviours/advance_to_first_non_empty.dart';
part 'empty_page_behaviours/show_empty_surface.dart';

/// What an async list does when a page settles with no items but [PaginationEndPolicy] reports that
/// more pages remain.
///
/// The underlying pager treats "zero items loaded" as its terminal empty state and shows the empty
/// surface, even when the end policy would keep paginating. With nothing on screen there is nothing
/// to scroll, so its scroll-driven fetch never fires and the list can't reach the pages that do hold
/// data. This seam decides what happens in that gap.
///
/// A sealed, injected, defaulted seam like [Refresh]: the default is [ShowEmptySurface] (the pager's
/// own behaviour, show the empty surface at once), switched to page-through by passing
/// [AdvanceToFirstNonEmpty]. Applies to [ListSmith.async] only; a `.sync` list holds all its items up
/// front and never paginates.
///
/// It only ever changes anything under an end policy that continues past an empty page, a raised
/// [StopOnEmptyPagesPolicy.emptyRunBeforeEnd] or a signal policy like [StopOnNullSignalPolicy]. Under
/// the default one-empty-page-ends policy an empty page *is* the end, so both behaviours show the empty
/// surface. Because advancing is opt-in, such a policy needs [AdvanceToFirstNonEmpty] set here too, or
/// the list shows the empty surface and stalls on the first empty page.
sealed class EmptyPageBehaviour {
  /// Const base constructor for the sealed hierarchy.
  const EmptyPageBehaviour();

  /// Whether the list should page past the current empty page, given [context].
  ///
  /// Called after each page settles. [ShowEmptySurface] always answers `false`; [AdvanceToFirstNonEmpty]
  /// answers `true` while the list is empty, more pages remain, and its `maxPages` cap is not yet
  /// reached. The orchestrator gathers the [EmptyPageContext] facts and acts on the answer, so the
  /// decision stays here rather than in a type-switch upstream.
  bool shouldAdvance(EmptyPageContext context);
}

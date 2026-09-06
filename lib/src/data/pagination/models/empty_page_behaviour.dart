/// @docImport '/src/data/presentation/models/async_list_surfaces.dart';
/// @docImport '/src/widgets/list_smith.dart';
/// @docImport 'pagination_end_policy.dart';
library;

import 'empty_page_context.dart';

part 'empty_page_behaviours/advance_to_first_non_empty.dart';
part 'empty_page_behaviours/show_empty_surface.dart';

/// What an async list does when a page settles with no items but [PaginationEndPolicy] says more
/// pages remain. Nothing on screen means nothing to scroll, so the pager's scroll-driven fetch
/// never fires and the pages that do hold data stay out of reach.
///
/// [ShowEmptySurface] (the default) shows the empty surface right there. [AdvanceToFirstNonEmpty]
/// pages through to the first page with items. It only bites under a policy that continues past an
/// empty page, so it pairs with a raised [StopOnEmptyPagesPolicy.emptyRunBeforeEnd] or a signal
/// policy. [ListSmith.async] only, since a `.sync` list never paginates.
sealed class EmptyPageBehaviour {
  /// Const base constructor.
  const new();

  /// Whether the list should page past the current empty page. Called after each page settles.
  bool shouldAdvance(EmptyPageContext context);
}

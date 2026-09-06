/// @docImport 'empty_page_behaviour.dart';
/// @docImport 'pagination_end_policy.dart';
library;

/// The facts an [EmptyPageBehaviour] sees when deciding whether to page past an empty page.
///
/// Rebuilt after each page settles, all of it derived from current state, so a behaviour stays a
/// pure function of its input.
final class EmptyPageContext {
  /// Whether the list currently displays no items (measured after de-duplication).
  final bool isEmpty;

  /// Whether [PaginationEndPolicy] reports that another page remains to fetch.
  final bool moreAvailable;

  /// The number of pages fetched so far.
  final int pagesLoaded;

  /// Creates a context over the current empty-page state.
  const new({required this.isEmpty, required this.moreAvailable, required this.pagesLoaded});
}

/// @docImport 'empty_page_behaviour.dart';
/// @docImport 'pagination_end_policy.dart';
library;

/// The facts an [EmptyPageBehaviour] sees when deciding whether to page past an empty page.
///
/// list_smith rebuilds one of these after each page settles and hands it to
/// [EmptyPageBehaviour.shouldAdvance]. Everything here is derived from the list's current state, so a
/// behaviour stays a pure function of its input and needs no state of its own.
final class EmptyPageContext {
  /// Whether the list currently displays no items (measured after de-duplication).
  final bool isEmpty;

  /// Whether [PaginationEndPolicy] reports that another page remains to fetch.
  final bool moreAvailable;

  /// The number of pages fetched so far.
  final int pagesLoaded;

  /// Creates a context over the current empty-page state.
  const EmptyPageContext({
    required this.isEmpty,
    required this.moreAvailable,
    required this.pagesLoaded,
  });
}

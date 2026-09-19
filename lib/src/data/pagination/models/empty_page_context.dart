/// @docImport 'empty_page_behaviour.dart';
/// @docImport 'pagination_end_policy.dart';
library;

/// What an [EmptyPageBehaviour] sees when deciding whether to page past an empty page.
///
/// Rebuilt after each page lands, so a behaviour stays a pure function of its input.
final class EmptyPageContext {
  /// Whether the list shows no items, counted after de-duplication.
  final bool isEmpty;

  /// Whether [PaginationEndPolicy] reports another page left to fetch.
  final bool isMoreAvailable;

  /// How many pages have been fetched so far.
  final int pagesLoaded;

  /// Creates it.
  const new({required this.isEmpty, required this.isMoreAvailable, required this.pagesLoaded});
}

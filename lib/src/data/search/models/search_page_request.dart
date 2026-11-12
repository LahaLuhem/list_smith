/// @docImport '/src/data/control/control.dart';
/// @docImport 'search_page_fetcher.dart';
library;

import '/src/data/pagination/pagination.dart';

/// The inputs of one search-page fetch, handed to a [SearchPageFetcher]. A [PageRequest] plus the committed
/// [query].
final class const SearchPageRequest({
  /// The query to search, trimmed and never empty: an empty one drives the normal [PageRequest] path
  /// instead. Typing gates it by the list's min length, a [ListSmithController.search] call by its
  /// own.
  required final String query,
  required super.pageIndex,
  required super.pageSize,
  required super.trigger,
  super.previousSignal,
}) extends PageRequest {
  /// Creates it.
  this;

  @override
  String toString() =>
      'SearchPageRequest('
      'query: $query, '
      'pageIndex: $pageIndex, '
      'pageSize: $pageSize, '
      'trigger: $trigger, '
      'previousSignal: $previousSignal'
      ')';
}

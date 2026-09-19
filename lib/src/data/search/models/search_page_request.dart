/// @docImport 'search_page_fetcher.dart';
library;

import '/src/data/pagination/models/page_request.dart';

/// The inputs of one search-page fetch, handed to a [SearchPageFetcher]. A [PageRequest] plus the committed
/// [query].
final class SearchPageRequest extends PageRequest {
  /// The query to search. Trimmed, past the min-length gate, and never empty: an empty query drives
  /// the normal [PageRequest] path instead.
  final String query;

  /// Creates it.
  const new({
    required this.query,
    required super.pageIndex,
    required super.pageSize,
    required super.trigger,
    super.previousSignal,
  });
}

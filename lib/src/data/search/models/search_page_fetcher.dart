/// @docImport '/src/data/pagination/models/page_fetcher.dart';
library;

/// Fetches one page of search results for an async list, for a given query.
///
/// Parallels [PageFetcher] but carries the committed `query`. `pageIndex` is 0-based and `pageSize`
/// is the list's configured page size; the returned `Iterable` is materialised once by list_smith at
/// the boundary. `query` arrives trimmed and past the min-length gate, and is never empty (an empty
/// query drives the normal [PageFetcher] path instead).
final class SearchPageFetcher<T extends Object> {
  final Future<Iterable<T>> Function(String query, int pageIndex, int pageSize) _fetch;

  /// Wraps a function returning one page of results for a `query`, 0-based `pageIndex`, and `pageSize`.
  const SearchPageFetcher(this._fetch);

  /// Fetches the page at [pageIndex] of results matching [query], with the given [pageSize].
  Future<Iterable<T>> call(String query, int pageIndex, int pageSize) =>
      _fetch(query, pageIndex, pageSize);
}

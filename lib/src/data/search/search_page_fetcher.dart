/// Fetches one page of search results for an async list, for a given query.
///
/// Parallels `PageFetcher` but carries the committed `query`. `pageIndex` is 0-based and `pageSize`
/// is the list's configured page size; the returned `Iterable` is materialised once by list_smith at
/// the boundary. `query` arrives trimmed and past the min-length gate, and is never empty (an empty
/// query drives the normal `PageFetcher` path instead).
typedef SearchPageFetcher<T extends Object> =
    Future<Iterable<T>> Function(String query, int pageIndex, int pageSize);

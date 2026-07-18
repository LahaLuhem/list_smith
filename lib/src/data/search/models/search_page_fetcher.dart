/// @docImport '/src/data/pagination/models/end_context.dart';
/// @docImport '/src/data/pagination/models/page_fetcher.dart';
library;

/// Fetches one page of search results for an async list, for a given query.
///
/// Parallels [PageFetcher] but carries the committed `query`. `pageIndex` is 0-based and `pageSize`
/// is the list's configured page size; the returned `Iterable` is materialised once by list_smith at
/// the boundary. `query` arrives trimmed and past the min-length gate, and is never empty (an empty
/// query drives the normal [PageFetcher] path instead).
///
/// Build one with [SearchPageFetcher.new] for items only, or [SearchPageFetcher.withSignal] to also
/// report an end signal for the end policy (see [EndContext.lastPageSignal]); with `withSignal` the
/// signal is handed back to the next search fetch as `previousSignal` (null for the first page), so a
/// cursor-driven search fetches the next page from the cursor the previous one returned.
final class SearchPageFetcher<T extends Object> {
  final Future<(Iterable<T>, Object?)> Function(
    String query,
    int pageIndex,
    int pageSize,
    Object? previousSignal,
  )
  _fetch;

  /// Whether this fetcher reports an end signal, i.e. it was built with [SearchPageFetcher.withSignal].
  final bool reportsSignal;

  /// Wraps a function returning one page of results for a `query`, 0-based `pageIndex`, and `pageSize`.
  factory SearchPageFetcher(
    Future<Iterable<T>> Function(String query, int pageIndex, int pageSize) fetch,
  ) => SearchPageFetcher._(
    (query, pageIndex, pageSize, _) async => (await fetch(query, pageIndex, pageSize), null),
    reportsSignal: false,
  );

  const SearchPageFetcher._(this._fetch, {required this.reportsSignal});

  /// Wraps a function that receives the previous page's `previousSignal` (null for the first page) and
  /// returns results with a new end signal, surfaced as [EndContext.lastPageSignal] and handed to the
  /// next fetch.
  factory SearchPageFetcher.withSignal(
    Future<(Iterable<T>, Object?)> Function(
      String query,
      int pageIndex,
      int pageSize,
      Object? previousSignal,
    )
    fetch,
  ) => SearchPageFetcher._(fetch, reportsSignal: true);

  /// Fetches the page at [pageIndex] of results matching [query], given the previous `previousSignal`,
  /// as items and an optional end signal.
  Future<(Iterable<T>, Object?)> call(
    String query,
    int pageIndex,
    int pageSize,
    Object? previousSignal,
  ) => _fetch(query, pageIndex, pageSize, previousSignal);
}

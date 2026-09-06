part of '../search.dart';

/// Async search on: a non-empty query switches the list to a search view fetched by [fetchPage].
///
/// [cachePolicy] decides what happens to the feed while you search, a clean reload each way by
/// default. See [SearchCachePolicy].
final class AsyncSearch<T extends Object> extends Search<T> {
  /// Fetches each page of results for the committed query.
  final SearchPageFetcher<T> fetchPage;

  /// How cached items carry across entering or leaving search. Defaults to [ReplaceCachePolicy].
  final SearchCachePolicy cachePolicy;

  /// Creates an async search over [fetchPage], with an optional [cachePolicy].
  const new({required this.fetchPage, this.cachePolicy = const ReplaceCachePolicy()});

  @override
  String toString() => 'AsyncSearch(cachePolicy: $cachePolicy)';
}

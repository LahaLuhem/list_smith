part of '../search.dart';

/// Async search on: a non-empty query switches the list to results fetched by [fetchPage].
///
/// [cachePolicy] decides what happens to the feed while you search. A clean reload each way by default.
final class AsyncSearch<T extends Object> extends Search<T> {
  /// Fetches each page of results for the committed query.
  final SearchPageFetcher<T> fetchPage;

  /// What happens to cached items when the list enters or leaves search. Defaults to [ReplaceCachePolicy].
  final SearchCachePolicy cachePolicy;

  /// Creates it.
  const new({required this.fetchPage, this.cachePolicy = const ReplaceCachePolicy()});

  @override
  String toString() => 'AsyncSearch(cachePolicy: $cachePolicy)';
}

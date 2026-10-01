part of '../search.dart';

/// Async search on: a non-empty query switches the list to results fetched by [fetchPage].
///
/// [cachePolicy] decides what happens to the feed while you search. A clean reload each way by default.
final class const AsyncSearch<T extends Object>({
  /// Fetches each page of results for the committed query.
  required final SearchPageFetcher<T> fetchPage,

  /// What happens to cached items when the list enters or leaves search. Defaults to [ReplaceCachePolicy].
  final SearchCachePolicy cachePolicy = const ReplaceCachePolicy(),
}) extends Search<T> {
  /// Creates it.
  this;

  @override
  String toString() => 'AsyncSearch(cachePolicy: $cachePolicy)';
}

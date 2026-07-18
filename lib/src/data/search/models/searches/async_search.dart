part of '../search.dart';

/// Async search on: a non-empty query switches the list to a search view fetched by [fetchPage].
///
/// [cachePolicy] governs how the normal list carries across the normal ↔ search switch (a clean
/// reload each way by default; see [SearchCachePolicy]). The fetcher and its policy live together
/// here, so a cache policy can only be set on a list that actually searches. Build [fetchPage] with
/// [SearchPageFetcher.new], or [SearchPageFetcher.withSignal] to report an end signal for a
/// signal-based end policy.
final class AsyncSearch<T extends Object> extends Search<T> {
  /// Fetches each page of results for the committed query.
  final SearchPageFetcher<T> fetchPage;

  /// How cached items carry across a normal ↔ search transition; defaults to [ReplaceCachePolicy].
  final SearchCachePolicy cachePolicy;

  /// Creates an async search over [fetchPage], with an optional [cachePolicy].
  const AsyncSearch({required this.fetchPage, this.cachePolicy = const ReplaceCachePolicy()});

  @override
  String toString() => 'AsyncSearch(cachePolicy: $cachePolicy)';
}

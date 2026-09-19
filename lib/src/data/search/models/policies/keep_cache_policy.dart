part of '../search_cache_policy.dart';

/// Keeps the feed across a search: put aside on the way in, restored when the query clears, so coming
/// back is instant.
///
/// For someone scrolling a long feed, searching, then clearing, who should land back where they were.
/// Each distinct query still starts clean, only the feed is kept. 3 exceptions to "no refetch":
///
/// - a page still loading when the search started is dropped and asked again
/// - a pull, `refresh()` or `invalidate()` while searching re-reads it in place on the way back
/// - a `reset()` while searching drops it, so it starts over
final class KeepCachePolicy extends SearchCachePolicy {
  /// Creates it.
  const new();

  @override
  String toString() => 'KeepCachePolicy()';
}

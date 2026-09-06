part of '../search_cache_policy.dart';

/// Keeps the normal-mode list across a search: snapshotted on the way in, restored when the query
/// clears, so coming back is instant with no refetch.
///
/// Reach for it when someone scrolling a long feed, searching, then clearing should land back where
/// they were. Each distinct query still starts clean, only the feed is kept. One exception to "no
/// refetch": a page still loading when the search started is dropped and asked again, since its
/// answer was aimed at the older list.
final class KeepCachePolicy extends SearchCachePolicy {
  /// Creates a policy that keeps and restores the normal-mode list.
  const new();

  @override
  String toString() => 'KeepCachePolicy()';
}

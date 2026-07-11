part of '../search_cache_policy.dart';

/// Preserves the normal-mode list across a search: its paging state is snapshotted on entering search
/// and restored when the query is cleared, so returning is instant with no refetch.
///
/// Identity-free: it snapshots and restores the whole paging state, needing no item-identity function.
/// Each distinct search query still starts clean; only the normal list is kept. Choose it when
/// scrolling a long normal list, searching, then clearing the query should land back exactly where
/// the user was.
final class KeepCachePolicy extends SearchCachePolicy {
  /// Creates a policy that keeps and restores the normal-mode list.
  const KeepCachePolicy();

  @override
  String toString() => 'KeepCachePolicy()';
}

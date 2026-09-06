part of '../search_cache_policy.dart';

/// Starts every mode clean: entering search, leaving it, and each new query all refetch from page 0.
///
/// The default. Reach for it when a fresh load each way is fine, or when coming back to the feed
/// should reflect whatever changed while searching.
final class ReplaceCachePolicy extends SearchCachePolicy {
  /// Creates the default replace policy.
  const new();

  @override
  String toString() => 'ReplaceCachePolicy()';
}

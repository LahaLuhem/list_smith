part of '../search_cache_policy.dart';

/// Starts every mode clean: entering search, leaving search, and each change of search query all
/// refetch from page 0.
///
/// The default, and identity-free: a transition is just a refresh, so nothing is cached or restored.
/// Choose it when a fresh load per mode is fine (the common case), or when returning to the normal
/// list should reflect anything that changed while searching.
final class ReplaceCachePolicy extends SearchCachePolicy {
  /// Creates the default replace policy.
  const ReplaceCachePolicy();

  @override
  String toString() => 'ReplaceCachePolicy()';
}

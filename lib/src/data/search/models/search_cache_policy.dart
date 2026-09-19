part 'policies/keep_cache_policy.dart';
part 'policies/replace_cache_policy.dart';

/// Decides what happens to an async list's cached items when it enters or leaves search.
///
/// [ReplaceCachePolicy] is the default. Only that boundary, so a change between 2 different queries
/// always starts clean.
sealed class SearchCachePolicy {
  /// Const base constructor.
  const new();
}

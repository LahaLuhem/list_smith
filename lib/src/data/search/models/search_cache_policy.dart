part 'policies/keep_cache_policy.dart';
part 'policies/replace_cache_policy.dart';

/// Decides how an async list's cached items carry across entering or leaving search.
///
/// [ReplaceCachePolicy] is the default. Only that boundary is governed, so a change between two
/// different queries always starts clean. Sealed, so a later strategy (a merge that de-dupes by
/// identity, say) can land without a breaking change.
sealed class SearchCachePolicy {
  /// Const base constructor.
  const new();
}

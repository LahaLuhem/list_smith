part 'policies/keep_cache_policy.dart';
part 'policies/replace_cache_policy.dart';

/// Decides how an async list's cached items carry across a normal ↔ search mode change.
///
/// A sealed, injected policy; list_smith ships [ReplaceCachePolicy] as the default. Sealed so more
/// strategies can be added later (for example a merge that dedupes by item identity) without a
/// breaking change, and so the search view handles every case exhaustively. A change between two
/// different searches always starts clean regardless of policy; the policy governs only the
/// normal ↔ search boundary.
sealed class SearchCachePolicy {
  /// Const base constructor for the sealed hierarchy.
  const SearchCachePolicy();
}

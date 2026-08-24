part 'policies/fail_on_unordered_policy.dart';
part 'policies/repair_headers_policy.dart';

/// What an async list does when its pages do not arrive grouped by key.
///
/// Async pages cannot be reordered, so the fetcher has to send all of one group before the next.
/// The sync path reorders for you and ignores this.
sealed class GroupOrderPolicy {
  /// Const base constructor for the sealed hierarchy.
  const new();
}

part 'policies/stop_on_empty_pages_policy.dart';

/// Decides when an async list has reached the end of its data.
///
/// A sealed, injected policy; list_smith ships [StopOnEmptyPagesPolicy] as the default. Sealed so
/// end-detection strategies can be added later (an explicit `hasMore`, a fixed page count, a server sentinel)
/// without a breaking change, and so the shell handles every case exhaustively.
sealed class PaginationEndPolicy {
  /// Const base constructor for the sealed hierarchy.
  const PaginationEndPolicy();
}

part 'policies/fixed_page_count_policy.dart';
part 'policies/stop_on_empty_pages_policy.dart';

/// Decides when an async list has reached the end of its data.
///
/// A sealed, injected policy; list_smith ships [StopOnEmptyPagesPolicy] (the default) and
/// [FixedPageCountPolicy]. Sealed so more end-detection strategies can be added later (an explicit
/// `hasMore`, a server sentinel) without a breaking change, and so the shell handles every case
/// exhaustively.
sealed class PaginationEndPolicy {
  /// Const base constructor for the sealed hierarchy.
  const PaginationEndPolicy();
}

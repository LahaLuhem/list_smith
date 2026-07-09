/// Decides when an async list has reached the end of its data.
///
/// A sealed, injected policy; list_smith ships [StopOnEmptyPages] as the default. Sealed so
/// end-detection strategies can be added later (an explicit `hasMore`, a fixed page count, a server sentinel)
/// without a breaking change, and so the shell handles every case exhaustively.
sealed class PaginationEndPolicy {
  /// Const base constructor for the sealed hierarchy.
  const PaginationEndPolicy();
}

/// Ends pagination after [emptyRunBeforeEnd] consecutive empty pages.
///
/// The default (`1`) stops on the first empty page, which fits the common feed. Raise it for sources
/// where an empty page is not the end: for example per-date calendar data, where a date with no entries
/// can still be followed by dates that do have entries.
final class StopOnEmptyPages extends PaginationEndPolicy {
  /// The number of consecutive empty pages that marks the end of the data.
  ///
  /// Defaults to `1`: the first empty page ends pagination. Must be at least 1.
  final int emptyRunBeforeEnd;

  /// Creates a policy that ends after [emptyRunBeforeEnd] consecutive empty pages.
  const StopOnEmptyPages({this.emptyRunBeforeEnd = 1})
    : assert(emptyRunBeforeEnd >= 1, 'emptyRunBeforeEnd must be at least 1.');

  @override
  String toString() => 'StopOnEmptyPages(emptyRunBeforeEnd: $emptyRunBeforeEnd)';
}

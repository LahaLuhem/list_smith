part of '../pagination_end_policy.dart';

/// Ends pagination after [emptyRunBeforeEnd] consecutive empty pages.
///
/// The default (`1`) stops on the first empty page, which fits the common feed. Raise it for sources
/// where an empty page is not the end: for example per-date calendar data, where a date with no entries
/// can still be followed by dates that do have entries.
final class StopOnEmptyPagesPolicy extends PaginationEndPolicy {
  /// The number of consecutive empty pages that marks the end of the data.
  ///
  /// Defaults to `1`: the first empty page ends pagination. Must be at least 1.
  final int emptyRunBeforeEnd;

  /// Creates a policy that ends after [emptyRunBeforeEnd] consecutive empty pages.
  const StopOnEmptyPagesPolicy({this.emptyRunBeforeEnd = 1})
    : assert(emptyRunBeforeEnd >= 1, 'emptyRunBeforeEnd must be at least 1.');

  @override
  bool hasReachedEnd(EndContext context) => context.trailingEmptyRun >= emptyRunBeforeEnd;

  @override
  String toString() => 'StopOnEmptyPagesPolicy(emptyRunBeforeEnd: $emptyRunBeforeEnd)';
}

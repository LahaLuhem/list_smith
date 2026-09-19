part of '../pagination_end_policy.dart';

/// Ends pagination after [emptyRunBeforeEnd] empty pages in a row. The default.
///
/// `1` stops on the 1st empty page, which fits most feeds. Raise it where an empty page isn't the end,
/// like a calendar paged by day.
final class StopOnEmptyPagesPolicy extends PaginationEndPolicy {
  /// How many empty pages in a row mark the end. Defaults to `1`, minimum `1`.
  final int emptyRunBeforeEnd;

  /// Ends after [emptyRunBeforeEnd] empty pages in a row.
  const new({this.emptyRunBeforeEnd = 1})
    : assert(emptyRunBeforeEnd >= 1, 'emptyRunBeforeEnd must be at least 1.');

  @override
  bool hasReachedEnd(EndContext context) => context.trailingEmptyRun >= emptyRunBeforeEnd;

  @override
  String toString() => 'StopOnEmptyPagesPolicy(emptyRunBeforeEnd: $emptyRunBeforeEnd)';
}

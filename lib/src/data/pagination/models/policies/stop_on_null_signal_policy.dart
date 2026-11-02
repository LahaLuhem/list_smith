part of '../pagination_end_policy.dart';

/// Ends pagination when a page's fetcher returns a `null` end signal, after at least 1 page.
///
/// Needs a `withSignal` fetcher whose signal is the next cursor. A `null` before the 1st page has loaded
/// ends nothing.
final class const StopOnNullSignalPolicy() extends PaginationEndPolicy {
  /// Creates it.
  this;

  @override
  bool hasReachedEnd(EndContext context) => context.pageCount > 0 && context.lastPageSignal == null;

  @override
  bool get requiresSignal => true;

  // Structurally covered by to_string_test.dart.
  // coverage:ignore-start
  @override
  String toString() => 'StopOnNullSignalPolicy()';
  // coverage:ignore-end
}

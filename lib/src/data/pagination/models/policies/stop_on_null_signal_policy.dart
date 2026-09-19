part of '../pagination_end_policy.dart';

/// Ends pagination when a page's fetcher returns a `null` end signal, after at least 1 page.
///
/// The cursor counterpart to [ExplicitHasMorePolicy]: needs a `withSignal` fetcher whose signal is the
/// next cursor. A `null` before the 1st page has loaded ends nothing.
final class StopOnNullSignalPolicy extends PaginationEndPolicy {
  /// Creates it.
  const new();

  @override
  bool hasReachedEnd(EndContext context) => context.pageCount > 0 && context.lastPageSignal == null;

  @override
  bool get requiresSignal => true;

  @override
  String toString() => 'StopOnNullSignalPolicy()';
}

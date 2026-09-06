part of '../pagination_end_policy.dart';

/// Ends pagination when a page's fetcher returns a `null` end signal, after at least one page.
///
/// The cursor counterpart to [ExplicitHasMorePolicy]: needs a `withSignal` fetcher whose signal is
/// the next cursor. A `null` before the first page has loaded ends nothing.
final class StopOnNullSignalPolicy extends PaginationEndPolicy {
  /// Creates a policy that ends when a page's fetcher returns a `null` signal (e.g. a null cursor).
  const new();

  @override
  bool hasReachedEnd(EndContext context) => context.pageCount > 0 && context.lastPageSignal == null;

  @override
  bool get requiresSignal => true;

  @override
  String toString() => 'StopOnNullSignalPolicy()';
}

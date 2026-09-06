part of '../pagination_end_policy.dart';

/// Ends pagination as soon as a page's fetcher reports `hasMore: false`.
///
/// Needs a `withSignal` fetcher whose signal is that bool. Stopping on the flag saves the trailing
/// empty page a count-based policy has to fetch to find the end. For a next-cursor source reach for
/// [StopOnNullSignalPolicy] instead.
final class ExplicitHasMorePolicy extends PaginationEndPolicy {
  /// Creates a policy that ends when a page's fetcher reports `hasMore: false`.
  const new();

  @override
  bool hasReachedEnd(EndContext context) => context.lastPageSignal == false;

  @override
  bool get requiresSignal => true;

  @override
  String toString() => 'ExplicitHasMorePolicy()';
}

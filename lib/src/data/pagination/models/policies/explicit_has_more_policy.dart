part of '../pagination_end_policy.dart';

/// Ends pagination once a `withSignal` fetcher's signal is `false`.
@Deprecated('Return the flag from PageFetcher.withHasMore instead. It goes at the next major.')
final class const ExplicitHasMorePolicy() extends PaginationEndPolicy {
  /// Creates it.
  @Deprecated('Return the flag from PageFetcher.withHasMore instead. It goes at the next major.')
  this;

  @override
  bool hasReachedEnd(EndContext context) => context.lastPageSignal == false;

  @override
  bool get requiresSignal => true;

  @override
  String toString() => 'ExplicitHasMorePolicy()';
}

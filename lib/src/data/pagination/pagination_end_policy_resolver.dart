import 'pagination_end_policy.dart';

/// Internal end-detection logic for [PaginationEndPolicy].
///
/// Kept as an extension in a separate, unexported file so the public policy stays pure data, while
/// the "has the data ended?" decision remains a small, widget-free unit that can be unit-tested
/// directly. It can't instead be a `@visibleForTesting` member on the policy: the shell calls this
/// from another library, which that annotation forbids (and it would not un-export it either).
extension PaginationEndPolicyResolver on PaginationEndPolicy {
  /// Whether pagination has reached its end, given the item count of each page fetched so far, in order.
  ///
  /// Neutral by design: only plain page sizes cross this boundary, never a paging-library type,
  /// so the policy stays decoupled from the async engine.
  bool hasReachedEnd(List<int> pageItemCounts) => switch (this) {
    StopOnEmptyPagesPolicy(:final emptyRunBeforeEnd) =>
      _trailingEmptyPageCount(pageItemCounts) >= emptyRunBeforeEnd,
  };
}

int _trailingEmptyPageCount(List<int> pageItemCounts) =>
    pageItemCounts.reversed.takeWhile((count) => count == 0).length;

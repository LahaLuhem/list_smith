// `_ShortLastPagePolicy` is a private fixture proving the open contract, not this file's subject, so
// its name intentionally differs from the filename.
// ignore_for_file: prefer-match-file-name

import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:list_smith/list_smith.dart';

void main() {
  final endDetection = BddFeature('Pagination end detection');

  const thresholdKey = 'threshold';
  const pageItemCountsKey = 'pageItemCounts';
  const endedKey = 'ended';
  const pageSizeKey = 'pageSize';

  Bdd(endDetection)
      .scenario('StopOnEmptyPages ends only after a run of consecutive trailing empty pages')
      .given('a StopOnEmptyPages policy with emptyRunBeforeEnd = <$thresholdKey>')
      .when('it inspects the per-page item counts <$pageItemCountsKey>')
      .then('it reports hasReachedEnd = <$endedKey>')
      // A single empty page ends the default; a mid-list gap does not accumulate.
      .example(val(thresholdKey, 1), val(pageItemCountsKey, <int>[3]), val(endedKey, false))
      .example(val(thresholdKey, 1), val(pageItemCountsKey, <int>[3, 0]), val(endedKey, true))
      .example(val(thresholdKey, 1), val(pageItemCountsKey, <int>[0]), val(endedKey, true))
      .example(val(thresholdKey, 2), val(pageItemCountsKey, <int>[3, 0]), val(endedKey, false))
      .example(val(thresholdKey, 2), val(pageItemCountsKey, <int>[3, 0, 0]), val(endedKey, true))
      .example(val(thresholdKey, 2), val(pageItemCountsKey, <int>[0, 3, 0]), val(endedKey, false))
      .example(val(thresholdKey, 2), val(pageItemCountsKey, <int>[0, 3, 0, 0]), val(endedKey, true))
      .run((ctx) {
        final policy = StopOnEmptyPagesPolicy(
          emptyRunBeforeEnd: ctx.example.val(thresholdKey) as int,
        );
        final pageItemCounts = ctx.example.val(pageItemCountsKey) as List<int>;

        check(
          policy.hasReachedEnd(EndContext(pageItemCounts: pageItemCounts, pageSize: 20)),
        ).equals(ctx.example.val(endedKey) as bool);
      });

  const countKey = 'count';
  Bdd(endDetection)
      .scenario('FixedPageCount ends once the given number of pages has been fetched')
      .given('a FixedPageCount policy with pageCount = <$countKey>')
      .when('it inspects the per-page item counts <$pageItemCountsKey>')
      .then('it reports hasReachedEnd = <$endedKey>')
      // Ends on the page count alone; a page's emptiness is ignored.
      .example(val(countKey, 3), val(pageItemCountsKey, <int>[5, 5]), val(endedKey, false))
      .example(val(countKey, 3), val(pageItemCountsKey, <int>[5, 5, 5]), val(endedKey, true))
      .example(val(countKey, 3), val(pageItemCountsKey, <int>[5, 0, 5]), val(endedKey, true))
      .example(val(countKey, 1), val(pageItemCountsKey, <int>[5]), val(endedKey, true))
      .example(val(countKey, 2), val(pageItemCountsKey, <int>[5]), val(endedKey, false))
      .run((ctx) {
        final policy = FixedPageCountPolicy(pageCount: ctx.example.val(countKey) as int);
        final pageItemCounts = ctx.example.val(pageItemCountsKey) as List<int>;

        check(
          policy.hasReachedEnd(EndContext(pageItemCounts: pageItemCounts, pageSize: 20)),
        ).equals(ctx.example.val(endedKey) as bool);
      });

  // The end policy is an open contract: a consumer can supply their own without a change to
  // list_smith. This one ends when the last page came back shorter than the page size (a common REST
  // idiom), proving the seam is usable from outside via EndContext alone.
  Bdd(endDetection)
      .scenario('a custom policy can end on a short last page')
      .given('a ShortLastPage policy over a list with pageSize = <$pageSizeKey>')
      .when('it inspects the per-page item counts <$pageItemCountsKey>')
      .then('it reports hasReachedEnd = <$endedKey>')
      .example(val(pageSizeKey, 5), val(pageItemCountsKey, <int>[5, 5]), val(endedKey, false))
      .example(val(pageSizeKey, 5), val(pageItemCountsKey, <int>[5, 3]), val(endedKey, true))
      .example(val(pageSizeKey, 5), val(pageItemCountsKey, <int>[5, 5, 0]), val(endedKey, true))
      .run((ctx) {
        const policy = _ShortLastPagePolicy();
        final pageItemCounts = ctx.example.val(pageItemCountsKey) as List<int>;
        final pageSize = ctx.example.val(pageSizeKey) as int;

        check(
          policy.hasReachedEnd(EndContext(pageItemCounts: pageItemCounts, pageSize: pageSize)),
        ).equals(ctx.example.val(endedKey) as bool);
      });
}

/// A consumer-authored end policy: ends when the most recent page held fewer than a full page of
/// items. Lives in the test to prove [PaginationEndPolicy] is implementable from outside list_smith.
final class _ShortLastPagePolicy extends PaginationEndPolicy {
  const _ShortLastPagePolicy();

  @override
  bool hasReachedEnd(EndContext context) => context.lastPageItemCount < context.pageSize;
}

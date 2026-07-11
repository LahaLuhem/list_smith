import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:list_smith/list_smith.dart';
import 'package:list_smith/src/data/pagination/extensions/pagination_end_policy_resolver_extension.dart';

void main() {
  final endDetection = BddFeature('Pagination end detection');

  const thresholdKey = 'threshold';
  const pageItemCountsKey = 'pageItemCounts';
  const endedKey = 'ended';
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

        check(policy.hasReachedEnd(pageItemCounts)).equals(ctx.example.val(endedKey) as bool);
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

        check(policy.hasReachedEnd(pageItemCounts)).equals(ctx.example.val(endedKey) as bool);
      });
}

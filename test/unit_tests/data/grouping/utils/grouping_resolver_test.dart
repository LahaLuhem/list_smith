import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:list_smith/src/data/grouping/grouping.dart';
import 'package:list_smith/src/data/presentation/presentation.dart';

void main() {
  final groupingFeature = BddFeature('Grouping resolution');

  // Group by the tens digit: 10/11/12 fall in group 1, 20/21 in group 2, 30 in group 3.
  int decade(int item) => item ~/ 10;

  const itemsKey = 'items';
  const bucketedKey = 'bucketed';

  Bdd(groupingFeature)
      .scenario(
        'buckets items into contiguous groups, first-appearance order, stable within a group',
      )
      .given('a tens-digit group key')
      .when('it buckets <$itemsKey>')
      .then('the order becomes <$bucketedKey>')
      // Empty in, empty out.
      .example(val(itemsKey, const <int>[]), val(bucketedKey, const <int>[]))
      // Already contiguous: order is untouched.
      .example(val(itemsKey, const [10, 11, 20]), val(bucketedKey, const [10, 11, 20]))
      // Interleaved: regrouped. Groups in first-appearance order, items stable within each.
      .example(
        val(itemsKey, const [10, 20, 11, 30, 21]),
        val(bucketedKey, const [10, 11, 20, 21, 30]),
      )
      .run((context) {
        final bucketed = bucketByGroup(context.example.val(itemsKey) as List<int>, decade);

        check(bucketed).deepEquals(context.example.val(bucketedKey) as List<int>);
      });

  const groupedHeaders = [(itemIndex: 0, key: 1), (itemIndex: 2, key: 2)];

  Bdd(groupingFeature)
      .scenario('grouped items stay as they are')
      .given('a tens-digit group key and RepairHeadersPolicy')
      .when('it resolves headers for items already grouped')
      .then('nothing gathers')
      .run((_) {
        final (headers: _, :gatheredItems) = resolveGroupHeaders(
          const [
            [10, 11],
            [20],
          ],
          decade,
          const RepairHeadersPolicy(),
          isReversed: false,
        );

        check(gatheredItems).isNull();
      });

  const outOfOrderPagesKey = 'outOfOrderPages';
  const gatheredKey = 'gathered';
  const isReversedKey = 'isReversed';
  const headersKey = 'headers';

  Bdd(groupingFeature)
      .scenario('the default policy gathers a key that comes back, one header per group')
      .given('a tens-digit group key and RepairHeadersPolicy')
      .when('it resolves headers for <$outOfOrderPagesKey>, reversed <$isReversedKey>')
      .then('the items gather into <$gatheredKey> under <$headersKey>')
      .example(
        val(outOfOrderPagesKey, const [
          [10, 20],
          [11],
        ]),
        val(isReversedKey, false),
        val(gatheredKey, const [10, 11, 20]),
        val(headersKey, groupedHeaders),
      )
      // On a reversed list a header shows above its group, so it goes after the group's last item.
      .example(
        val(outOfOrderPagesKey, const [
          [10, 20],
          [11],
        ]),
        val(isReversedKey, true),
        val(gatheredKey, const [10, 11, 20]),
        val(headersKey, const [(itemIndex: 1, key: 1), (itemIndex: 2, key: 2)]),
      )
      .run((context) {
        final (:headers, :gatheredItems) = resolveGroupHeaders(
          context.example.val(outOfOrderPagesKey) as List<List<int>>,
          decade,
          const RepairHeadersPolicy(),
          isReversed: context.example.val(isReversedKey) as bool,
        );

        check(gatheredItems).isNotNull().deepEquals(context.example.val(gatheredKey) as List<int>);
        check(headers).deepEquals(context.example.val(headersKey) as List<GroupHeader>);
      });

  Bdd(groupingFeature)
      .scenario('FailOnUnorderedPolicy throws on out-of-order items, in release too')
      .given('a tens-digit group key and FailOnUnorderedPolicy')
      .when('a group key comes back after another one')
      .then('it throws a StateError instead of drawing anything')
      .run((_) {
        check(
          () => resolveGroupHeaders(
            const [
              [10, 20],
              [11],
            ],
            decade,
            const FailOnUnorderedPolicy(),
            isReversed: false,
          ),
        ).throws<StateError>();

        // Properly grouped items: no throw, same headers as the default.
        check(
          resolveGroupHeaders(
            const [
              [10, 11],
              [20],
            ],
            decade,
            const FailOnUnorderedPolicy(),
            isReversed: false,
          ).headers,
        ).deepEquals(groupedHeaders);
      });

  const headerPagesKey = 'headerPages';

  Bdd(groupingFeature)
      .scenario(
        "puts a header on each group's run, even across pages, after its last item when reversed",
      )
      .given('a tens-digit group key')
      .when('it finds the headers for <$headerPagesKey>, reversed <$isReversedKey>')
      .then('they are <$headersKey>')
      .example(
        val(headerPagesKey, const <List<int>>[]),
        val(isReversedKey, false),
        val(headersKey, const <GroupHeader>[]),
      )
      // Group 1 runs across the 1st page boundary, group 3 starts a page.
      .example(
        val(headerPagesKey, const [
          [10],
          [11, 20],
          [30],
        ]),
        val(isReversedKey, false),
        val(headersKey, const [
          (itemIndex: 0, key: 1),
          (itemIndex: 2, key: 2),
          (itemIndex: 3, key: 3),
        ]),
      )
      .example(
        val(headerPagesKey, const [
          [10],
          [11, 20],
          [30],
        ]),
        val(isReversedKey, true),
        val(headersKey, const [
          (itemIndex: 1, key: 1),
          (itemIndex: 2, key: 2),
          (itemIndex: 3, key: 3),
        ]),
      )
      .run((context) {
        final headers = groupHeadersIfContiguous(
          context.example.val(headerPagesKey) as List<List<int>>,
          decade,
          isReversed: context.example.val(isReversedKey) as bool,
        );

        check(headers).isNotNull().deepEquals(context.example.val(headersKey) as List<GroupHeader>);
      });

  Bdd(groupingFeature)
      .scenario('a key coming back after its run ended gives no headers, since it needs gathering')
      .given('a tens-digit group key')
      .when('a group key comes back on a later page')
      .then('there are no headers yet')
      .run((_) {
        const pages = [
          [10, 20],
          [11],
        ];

        check(groupHeadersIfContiguous(pages, decade, isReversed: false)).isNull();
      });
}

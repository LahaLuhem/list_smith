import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:list_smith/src/data/grouping/grouping.dart';
import 'package:list_smith/src/data/presentation/presentation.dart';

void main() {
  final groupingFeature = BddFeature('Grouping resolution');

  // Group by the tens digit: 10/11/12 fall in group 1, 20/21 in group 2, 30 in group 3.
  int decade(int item) => item ~/ 10;

  Bdd(groupingFeature)
      .scenario(
        'buckets items into contiguous groups, first-appearance order, stable within a group',
      )
      .given('a tens-digit group key')
      .when('it buckets items whose groups first appear out of key order, 21 before 20')
      .then('each group gathers where it first appeared, its items in the order they came')
      .run((_) {
        check(bucketByGroup(const [21, 10, 20, 30, 11], decade))
            .deepEquals(const [21, 20, 10, 11, 30]);
      });

  const groupedHeaders = [(itemIndex: 0, key: 1), (itemIndex: 2, key: 2)];

  const outOfOrderPagesKey = 'outOfOrderPages';
  const gatheredKey = 'gathered';
  const headersKey = 'headers';

  Bdd(groupingFeature)
      .scenario('the default policy gathers a key that comes back, one header per group')
      .given('a tens-digit group key and RepairHeadersPolicy')
      .when('it resolves headers for <$outOfOrderPagesKey>')
      .then('the items gather into <$gatheredKey> under <$headersKey>')
      .example(
        val(outOfOrderPagesKey, const [
          [10, 20],
          [11],
        ]),
        val(gatheredKey, const [10, 11, 20]),
        val(headersKey, groupedHeaders),
      )
      .run((context) {
        final (:headers, :gatheredItems) = resolveGroupHeaders(
          context.example.val(outOfOrderPagesKey) as List<List<int>>,
          decade,
          const RepairHeadersPolicy(),
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
          ).headers,
        ).deepEquals(groupedHeaders);
      });

  Bdd(groupingFeature)
      .scenario("puts a header at the start of each group's run, even across pages")
      .given('a tens-digit group key')
      .when('group 1 runs across the 1st page boundary and group 3 starts a page')
      .then('each group gets one header, at its 1st item')
      .run((_) {
        final headers = groupHeadersIfContiguous(const [
          [10],
          [11, 20],
          [30],
        ], decade);

        check(headers).isNotNull().deepEquals(const [
          (itemIndex: 0, key: 1),
          (itemIndex: 2, key: 2),
          (itemIndex: 3, key: 3),
        ]);
      });
}

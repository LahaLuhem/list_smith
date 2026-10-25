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
      .scenario('the default policy leaves properly grouped items alone')
      .given('a tens-digit group key and RepairHeadersPolicy')
      .when('it resolves headers for contiguous items')
      .then('every group gets its header')
      .run((_) {
        final headers = resolveGroupHeaders(
          const [10, 11, 20],
          decade,
          const RepairHeadersPolicy(),
          isReversed: false,
        );

        check(headers).deepEquals(groupedHeaders);
      });

  Bdd(groupingFeature)
      .scenario('FailOnUnorderedPolicy throws on out-of-order items, in release too')
      .given('a tens-digit group key and FailOnUnorderedPolicy')
      .when('a group key comes back after another one')
      .then('it throws a StateError instead of drawing anything')
      .run((_) {
        check(
          () => resolveGroupHeaders(
            const [10, 20, 11],
            decade,
            const FailOnUnorderedPolicy(),
            isReversed: false,
          ),
        ).throws<StateError>();

        // Properly grouped items: no throw, same headers as the default.
        check(
          resolveGroupHeaders(
            const [10, 11, 20],
            decade,
            const FailOnUnorderedPolicy(),
            isReversed: false,
          ),
        ).deepEquals(groupedHeaders);
      });

  const headerItemsKey = 'headerItems';
  const isReversedKey = 'isReversed';
  const headersKey = 'headers';

  Bdd(groupingFeature)
      .scenario("puts one header on each key's 1st run, after its last item on a reversed list")
      .given('a tens-digit group key')
      .when('it finds the headers for <$headerItemsKey>, reversed <$isReversedKey>')
      .then('they are <$headersKey>')
      .example(
        val(headerItemsKey, const <int>[]),
        val(isReversedKey, false),
        val(headersKey, const <GroupHeader>[]),
      )
      .example(
        val(headerItemsKey, const [10, 11, 20, 30]),
        val(isReversedKey, false),
        val(headersKey, const [
          (itemIndex: 0, key: 1),
          (itemIndex: 2, key: 2),
          (itemIndex: 3, key: 3),
        ]),
      )
      // On a reversed list a header shows above its group, so it goes after the group's last item.
      .example(
        val(headerItemsKey, const [10, 11, 20, 30]),
        val(isReversedKey, true),
        val(headersKey, const [
          (itemIndex: 1, key: 1),
          (itemIndex: 2, key: 2),
          (itemIndex: 3, key: 3),
        ]),
      )
      // A key coming back gets no 2nd header, either way round.
      .example(
        val(headerItemsKey, const [10, 20, 11]),
        val(isReversedKey, false),
        val(headersKey, const [(itemIndex: 0, key: 1), (itemIndex: 1, key: 2)]),
      )
      .example(
        val(headerItemsKey, const [10, 20, 11]),
        val(isReversedKey, true),
        val(headersKey, const [(itemIndex: 0, key: 1), (itemIndex: 1, key: 2)]),
      )
      .run((context) {
        final headers = groupHeadersByFirstRun(
          context.example.val(headerItemsKey) as List<int>,
          decade,
          isReversed: context.example.val(isReversedKey) as bool,
        );

        check(headers).deepEquals(context.example.val(headersKey) as List<GroupHeader>);
      });

  const contiguousItemsKey = 'contiguousItems';
  const contiguousKey = 'contiguous';

  Bdd(groupingFeature)
      .scenario('reports whether groups stay contiguous, flagging a key that recurs after its run')
      .given('a tens-digit group key')
      .when('it checks <$contiguousItemsKey>')
      .then('groupsAreContiguous is <$contiguousKey>')
      // Empty and single-group inputs are trivially contiguous.
      .example(val(contiguousItemsKey, const <int>[]), val(contiguousKey, true))
      .example(val(contiguousItemsKey, const [10, 11, 12]), val(contiguousKey, true))
      // Distinct groups back to back are contiguous.
      .example(val(contiguousItemsKey, const [10, 11, 20, 30]), val(contiguousKey, true))
      // A group key returning after another intervened is not contiguous.
      .example(val(contiguousItemsKey, const [10, 20, 11]), val(contiguousKey, false))
      .run((context) {
        final contiguous = groupsAreContiguous(
          context.example.val(contiguousItemsKey) as List<int>,
          decade,
        );

        check(contiguous).equals(context.example.val(contiguousKey) as bool);
      });
}

import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:list_smith/src/data/grouping/models/group_order_policy.dart';
import 'package:list_smith/src/data/grouping/utils/grouping_resolver.dart';

void main() {
  final grouping = BddFeature('Grouping resolution');

  // Group by the tens digit: 10/11/12 fall in group 1, 20/21 in group 2, 30 in group 3.
  int decade(int item) => item ~/ 10;

  const itemsKey = 'items';
  const bucketedKey = 'bucketed';

  Bdd(grouping)
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
      // Interleaved: regrouped; groups in first-appearance order, items stable within each.
      .example(
        val(itemsKey, const [10, 20, 11, 30, 21]),
        val(bucketedKey, const [10, 11, 20, 21, 30]),
      )
      .run((ctx) {
        final bucketed = bucketByGroup(ctx.example.val(itemsKey) as List<int>, decade);

        check(bucketed).deepEquals(ctx.example.val(bucketedKey) as List<int>);
      });

  const flagItemsKey = 'flagItems';
  const flagsKey = 'flags';

  Bdd(grouping)
      .scenario('flags the first sighting of each group key, and only that one')
      .given('a tens-digit group key')
      .when('it flags headers for <$flagItemsKey>')
      .then('the flags are <$flagsKey>')
      // Empty in, empty out.
      .example(val(flagItemsKey, const <int>[]), val(flagsKey, const <bool>[]))
      // One header per group, on the item that opens it.
      .example(
        val(flagItemsKey, const [10, 11, 20, 30]),
        val(flagsKey, const [true, false, true, true]),
      )
      // A key coming back is not a second header. That is the repair.
      .example(val(flagItemsKey, const [10, 20, 11]), val(flagsKey, const [true, true, false]))
      .run((ctx) {
        final flags = headerFlagsByFirstSighting(
          ctx.example.val(flagItemsKey) as List<int>,
          decade,
        );

        check(flags).deepEquals(ctx.example.val(flagsKey) as List<bool>);
      });

  Bdd(grouping)
      .scenario('the default policy leaves properly grouped items alone')
      .given('a tens-digit group key and RepairHeadersPolicy')
      .when('it resolves headers for contiguous items')
      .then('every group opener is flagged')
      .run((_) {
        final flags = resolveHeaderFlags(const [10, 11, 20], decade, const RepairHeadersPolicy());

        check(flags).deepEquals(const [true, false, true]);
      });

  Bdd(grouping)
      .scenario('FailOnUnorderedPolicy throws on out-of-order items, in release too')
      .given('a tens-digit group key and FailOnUnorderedPolicy')
      .when('a group key comes back after another one')
      .then('it throws a StateError instead of drawing anything')
      .run((_) {
        check(() => resolveHeaderFlags(const [10, 20, 11], decade, const FailOnUnorderedPolicy()))
            .throws<StateError>();

        // Properly grouped items: no throw, same flags as the default.
        check(resolveHeaderFlags(const [10, 11, 20], decade, const FailOnUnorderedPolicy()))
            .deepEquals(const [true, false, true]);
      });

  const contiguousItemsKey = 'contiguousItems';
  const contiguousKey = 'contiguous';

  Bdd(grouping)
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
      .run((ctx) {
        final contiguous = groupsAreContiguous(
          ctx.example.val(contiguousItemsKey) as List<int>,
          decade,
        );

        check(contiguous).equals(ctx.example.val(contiguousKey) as bool);
      });
}

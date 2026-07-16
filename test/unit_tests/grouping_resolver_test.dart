import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
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

  const previousKey = 'previous';
  const currentKey = 'current';
  const startKey = 'start';

  Bdd(grouping)
      .scenario('marks a group start at the first item and wherever the key changes')
      .given('a tens-digit group key')
      .when('the previous item is <$previousKey> and the current is <$currentKey>')
      .then('isGroupStart is <$startKey>')
      // No previous item: the first item always starts a group.
      .example(val(previousKey, null), val(currentKey, 10), val(startKey, true))
      // Same key as the previous item: not a start.
      .example(val(previousKey, 10), val(currentKey, 11), val(startKey, false))
      // Key changed from the previous item: a start.
      .example(val(previousKey, 11), val(currentKey, 20), val(startKey, true))
      .run((ctx) {
        final started = isGroupStart(
          ctx.example.val(previousKey) as int?,
          ctx.example.val(currentKey) as int,
          decade,
        );

        check(started).equals(ctx.example.val(startKey) as bool);
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

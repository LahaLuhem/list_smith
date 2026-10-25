import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:list_smith/src/data/presentation/presentation.dart';

void main() {
  final idsFeature = BddFeature('First of each id');

  // The id is the tens digit, so 2 items can share one and still tell apart.
  int decade(int item) => item ~/ 10;

  const itemsKey = 'items';
  const keptKey = 'kept';
  const repeatedIdKey = 'repeatedId';

  Bdd(idsFeature)
      .scenario('keeps the 1st item of each id, in order, and names an id that repeats')
      .given('items whose id is their tens digit')
      .when('it keeps the 1st of each id in <$itemsKey>')
      .then('it keeps <$keptKey> and names <$repeatedIdKey>')
      // Empty in, empty out.
      .example(val(itemsKey, const <int>[]), val(keptKey, const <int>[]), val(repeatedIdKey, null))
      .example(
        val(itemsKey, const [10, 20, 30]),
        val(keptKey, const [10, 20, 30]),
        val(repeatedIdKey, null),
      )
      // The 1st item stays, every later one with its id goes.
      .example(
        val(itemsKey, const [10, 11, 20, 12]),
        val(keptKey, const [10, 20]),
        val(repeatedIdKey, 1),
      )
      .run((context) {
        final (:items, :repeatedId) = firstOfEachId(
          context.example.val(itemsKey) as List<int>,
          decade,
        );

        check(items).deepEquals(context.example.val(keptKey) as List<int>);
        check(repeatedId).equals(context.example.val(repeatedIdKey));
      });
}

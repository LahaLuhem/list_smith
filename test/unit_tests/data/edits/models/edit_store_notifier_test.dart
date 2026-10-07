import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:list_smith/src/data/edits/models/edit_store_notifier.dart';

void main() {
  final storeFeature = BddFeature('Edit store');

  Bdd(storeFeature)
      .scenario('every edit moves the value on and tells the listeners, so the display re-runs')
      .given('a store with a listener')
      .when('an item is changed, then removed')
      .then('each edit moves the value on and notifies once')
      .run((_) {
        final editStoreNotifier = EditStoreNotifier<int>();
        var notifiedCount = 0;
        editStoreNotifier.addListener(() => notifiedCount++);
        final startValue = editStoreNotifier.value;

        editStoreNotifier.book(1, 10);
        final changedValue = editStoreNotifier.value;
        editStoreNotifier.book(1, null);

        check(notifiedCount).equals(2);
        check(changedValue).isGreaterThan(startValue);
        check(editStoreNotifier.value).isGreaterThan(changedValue);
        editStoreNotifier.dispose();
      });

  const readOffsetsKey = 'read offsets';
  const isKeptKey = 'is kept';

  Bdd(storeFeature)
      .scenario('an edit stays while any page was read before it')
      .given('an edit, and pages read at <$readOffsetsKey> from it')
      .when('the store drops what those pages caught up with')
      .then('the edit is kept: <$isKeptKey>')
      .example(val(readOffsetsKey, const [-1, 0]), val(isKeptKey, true))
      .example(val(readOffsetsKey, const [0, 1]), val(isKeptKey, false))
      .run((context) {
        final editStoreNotifier = EditStoreNotifier<int>()..book(1, 10);
        final editStamp = editStoreNotifier.value;
        final readOffsets = context.example.val(readOffsetsKey) as List<int>;

        editStoreNotifier.dropCaughtUp(readOffsets.map((offset) => editStamp + offset));

        check(editStoreNotifier.isEmpty).equals(!(context.example.val(isKeptKey) as bool));
        editStoreNotifier.dispose();
      });
}

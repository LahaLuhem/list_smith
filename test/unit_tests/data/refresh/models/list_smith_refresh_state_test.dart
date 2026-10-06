import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:list_smith/list_smith.dart';

import '../../../../support/support.dart';

void main() {
  final refreshStateFeature = BddFeature('ListSmithRefreshState value semantics');

  Bdd(refreshStateFeature)
      .scenario('equal phase, value and direction compare equal and share a hashCode')
      .given('two refresh states with the same phase, value and direction')
      .when('they are compared')
      .then('they are equal and their hashCodes match')
      .run((_) {
        const one = ListSmithRefreshState(phase: .armed, value: 1, pullDirection: .up);
        const same = ListSmithRefreshState(phase: .armed, value: 1, pullDirection: .up);

        check(one).equals(same);
        check(one.hashCode).equals(same.hashCode);
      });

  Bdd(refreshStateFeature)
      .scenario('a difference in phase, value or direction compares unequal')
      .given('a base refresh state')
      .when('it is compared to states differing in phase, value or direction')
      .then('none is equal to the base')
      .run((_) {
        const base = ListSmithRefreshState(phase: .dragging, value: 0);
        const otherPhase = ListSmithRefreshState(phase: .armed, value: 0);
        const otherValue = ListSmithRefreshState(phase: .dragging, value: 0.5);
        const otherDirection = ListSmithRefreshState(
          phase: .dragging,
          value: 0,
          pullDirection: .up,
        );

        check(base == otherPhase).isFalse();
        check(base == otherValue).isFalse();
        check(base == otherDirection).isFalse();
      });

  const valueKey = 'value';
  Bdd(refreshStateFeature)
      .scenario('every refresh state reads as itself in a log')
      .given('the refresh state <$valueKey>')
      .when('it is turned into a string')
      .then("it reads as itself, not as Dart's default Instance of")
      .example(
        val(valueKey, const ListSmithRefreshState(phase: .armed, value: 1, pullDirection: .up)),
      )
      .run((context) => check(context.example.val(valueKey) as Object).readsAsItself());
}

import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:list_smith/list_smith.dart';

import '../../../../support/support.dart';

void main() {
  final logFormFeature = BddFeature('EditTransition log form');

  const valueKey = 'value';
  Bdd(logFormFeature)
      .scenario('every edit transition reads as itself in a log')
      .given('the edit transition <$valueKey>')
      .when('it is turned into a string')
      .then("it reads as itself, not as Dart's default Instance of")
      .example(
        val(
          valueKey,
          const EditTransition(
            duration: Duration(milliseconds: 250),
            transitionBuilder: AnimatedSwitcher.defaultTransitionBuilder,
          ),
        ),
      )
      .example(val(valueKey, const NoEditTransition()))
      .run((context) => check(context.example.val(valueKey) as Object).readsAsItself());
}

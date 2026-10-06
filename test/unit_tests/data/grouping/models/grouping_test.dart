import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:list_smith/list_smith.dart';

import '../../../../support/support.dart';

void main() {
  final logFormFeature = BddFeature('Grouping log form');

  const valueKey = 'value';
  Bdd(logFormFeature)
      .scenario('every grouping reads as itself in a log')
      .given('the grouping <$valueKey>')
      .when('it is turned into a string')
      .then("it reads as itself, not as Dart's default Instance of")
      .example(
        val(
          valueKey,
          Grouping.by<int, int>(groupBy: (item) => item, headerBuilder: (_, key) => Text('$key')),
        ),
      )
      .example(val(valueKey, const NoGrouping<int>()))
      .run((context) => check(context.example.val(valueKey) as Object).readsAsItself());
}

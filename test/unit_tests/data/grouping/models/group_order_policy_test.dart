import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:list_smith/list_smith.dart';

import '../../../../support/support.dart';

void main() {
  final logFormFeature = BddFeature('GroupOrderPolicy log form');

  const valueKey = 'value';
  Bdd(logFormFeature)
      .scenario('every group order policy reads as itself in a log')
      .given('the group order policy <$valueKey>')
      .when('it is turned into a string')
      .then("it reads as itself, not as Dart's default Instance of")
      .example(val(valueKey, const RepairHeadersPolicy()))
      .example(val(valueKey, const FailOnUnorderedPolicy()))
      .run((context) => check(context.example.val(valueKey) as Object).readsAsItself());
}

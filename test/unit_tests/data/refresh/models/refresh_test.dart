import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:list_smith/list_smith.dart';

import '../../../../support/support.dart';

void main() {
  final logFormFeature = BddFeature('Refresh log form');

  const valueKey = 'value';
  Bdd(logFormFeature)
      .scenario('every refresh reads as itself in a log')
      .given('the refresh <$valueKey>')
      .when('it is turned into a string')
      .then("it reads as itself, not as Dart's default Instance of")
      .example(val(valueKey, const PullToRefresh()))
      .example(val(valueKey, const NoRefresh()))
      .run((context) => check(context.example.val(valueKey) as Object).readsAsItself());
}

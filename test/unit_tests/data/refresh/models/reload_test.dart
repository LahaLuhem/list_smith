import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:list_smith/list_smith.dart';

import '../../../../support/support.dart';

void main() {
  final logFormFeature = BddFeature('Reload log form');

  const valueKey = 'value';
  Bdd(logFormFeature)
      .scenario('every reload reads as itself in a log')
      .given('the reload <$valueKey>')
      .when('it is turned into a string')
      .then("it reads as itself, not as Dart's default Instance of")
      .example(val(valueKey, const ReloadToCurrentDepth()))
      .example(val(valueKey, const ResetToFirstPage()))
      .run((context) => check(context.example.val(valueKey) as Object).readsAsItself());
}

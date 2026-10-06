import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:list_smith/list_smith.dart';

import '../../../../support/support.dart';

void main() {
  final logFormFeature = BddFeature('Search log form');

  const valueKey = 'value';
  Bdd(logFormFeature)
      .scenario('every search reads as itself in a log')
      .given('the search <$valueKey>')
      .when('it is turned into a string')
      .then("it reads as itself, not as Dart's default Instance of")
      .example(val(valueKey, AsyncSearch(fetchPage: SearchPageFetcher<int>((_) async => const []))))
      .example(val(valueKey, const NoSearch()))
      .run((context) => check(context.example.val(valueKey) as Object).readsAsItself());
}

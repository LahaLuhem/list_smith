import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:list_smith/src/data/pagination/models/paging_state.dart';

import '../../../../support/support.dart';

void main() {
  final logFormFeature = BddFeature('PagingState log form');

  const valueKey = 'value';
  Bdd(logFormFeature)
      .scenario('every paging state reads as itself in a log')
      .given('the paging state <$valueKey>')
      .when('it is turned into a string')
      .then("it reads as itself, not as Dart's default Instance of")
      .example(val(valueKey, const PagingState<int>()))
      .run((context) => check(context.example.val(valueKey) as Object).readsAsItself());
}

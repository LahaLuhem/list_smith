import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:list_smith/list_smith.dart';

void main() {
  final behavioursFeature = BddFeature('EmptyPageBehaviour.shouldAdvance');

  Bdd(behavioursFeature)
      .scenario('AdvanceToFirstNonEmpty stops once the page has items')
      .given('an uncapped AdvanceToFirstNonEmpty')
      .when('the displayed page is not empty')
      .then('it does not advance')
      .run((_) {
        const context = EmptyPageContext(isEmpty: false, isMoreAvailable: true, pagesLoaded: 1);

        check(const AdvanceToFirstNonEmpty().shouldAdvance(context)).isFalse();
      });
}

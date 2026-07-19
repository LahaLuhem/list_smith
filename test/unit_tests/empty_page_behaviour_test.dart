import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:list_smith/list_smith.dart';

void main() {
  final behaviours = BddFeature('EmptyPageBehaviour.shouldAdvance');

  EmptyPageContext ctx({bool isEmpty = true, bool moreAvailable = true, int pagesLoaded = 1}) =>
      EmptyPageContext(isEmpty: isEmpty, moreAvailable: moreAvailable, pagesLoaded: pagesLoaded);

  Bdd(behaviours)
      .scenario('ShowEmptySurface never advances, even on an empty page with more pages')
      .given('the show-empty-surface behaviour')
      .when('probed on an empty page that has more pages')
      .then('it declines to advance')
      .run((_) {
        check(const ShowEmptySurface().shouldAdvance(ctx())).isFalse();
      });

  Bdd(behaviours)
      .scenario('AdvanceToFirstNonEmpty advances while empty, with more pages, under the cap')
      .given('an uncapped AdvanceToFirstNonEmpty')
      .when('probed on an empty page that has more pages')
      .then('it advances')
      .run((_) {
        check(const AdvanceToFirstNonEmpty().shouldAdvance(ctx())).isTrue();
      });

  Bdd(behaviours)
      .scenario('AdvanceToFirstNonEmpty stops once the page has items')
      .given('an uncapped AdvanceToFirstNonEmpty')
      .when('the displayed page is not empty')
      .then('it does not advance')
      .run((_) {
        check(const AdvanceToFirstNonEmpty().shouldAdvance(ctx(isEmpty: false))).isFalse();
      });

  Bdd(behaviours)
      .scenario('AdvanceToFirstNonEmpty stops at the true end')
      .given('an uncapped AdvanceToFirstNonEmpty')
      .when('the end policy reports no more pages')
      .then('it does not advance')
      .run((_) {
        check(const AdvanceToFirstNonEmpty().shouldAdvance(ctx(moreAvailable: false))).isFalse();
      });

  Bdd(behaviours)
      .scenario('AdvanceToFirstNonEmpty gives up once maxPages is reached')
      .given('an AdvanceToFirstNonEmpty capped at three pages')
      .when('the fetched-page count reaches the cap')
      .then('it advances under the cap but not at it')
      .run((_) {
        const capped = AdvanceToFirstNonEmpty(maxPages: 3);

        check(capped.shouldAdvance(ctx(pagesLoaded: 2))).isTrue();
        check(capped.shouldAdvance(ctx(pagesLoaded: 3))).isFalse();
      });
}

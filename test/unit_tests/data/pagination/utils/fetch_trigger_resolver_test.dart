import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:list_smith/src/data/pagination/pagination.dart';

void main() {
  final triggerResolutionFeature = BddFeature('Fetch trigger resolution');

  const pageKey = 'pageIndex';
  const pendingKey = 'pending';
  const failedKey = 'lastFailedPageIndex';
  const triggerKey = 'trigger';

  Bdd(triggerResolutionFeature)
      .scenario('resolves why a page was fetched from the pending trigger and the page state')
      .given('page <$pageKey>, a pending <$pendingKey>, and a last-failed <$failedKey>')
      .when('the trigger is resolved')
      .then('it is <$triggerKey>')
      // A failure on another page leaves this one alone.
      .example(
        val(pageKey, 3),
        val(pendingKey, null),
        val(failedKey, 1),
        val(triggerKey, FetchTrigger.nextPage),
      )
      // A pending trigger wins over a retry.
      .example(
        val(pageKey, 0),
        val(pendingKey, FetchTrigger.queryChanged),
        val(failedKey, 0),
        val(triggerKey, FetchTrigger.queryChanged),
      )
      .run((context) {
        final trigger = resolveTrigger(
          pageIndex: context.example.val(pageKey) as int,
          pending: context.example.val(pendingKey) as FetchTrigger?,
          lastFailedPageIndex: context.example.val(failedKey) as int?,
        );

        check(trigger).equals(context.example.val(triggerKey) as FetchTrigger);
      });

  Bdd(triggerResolutionFeature)
      .scenario('page 0 read again because rows above it went reports invalidated, not a cold load')
      .given('page 0, read again, with nothing pending or failed')
      .when('the trigger is resolved')
      .then('it is invalidated')
      .run((_) {
        final trigger = resolveTrigger(
          pageIndex: 0,
          pending: null,
          lastFailedPageIndex: null,
          isReread: true,
        );

        check(trigger).equals(FetchTrigger.invalidated);
      });
}

import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:list_smith/list_smith.dart';
import 'package:list_smith/src/data/pagination/utils/fetch_trigger_resolver.dart';

void main() {
  final triggerResolution = BddFeature('Fetch trigger resolution');

  const pageKey = 'pageIndex';
  const pendingKey = 'pending';
  const failedKey = 'lastFailedPageIndex';
  const triggerKey = 'trigger';

  Bdd(triggerResolution)
      .scenario('resolves why a page was fetched from the latch and the page state')
      .given('page <$pageKey>, a pending <$pendingKey>, and a last-failed <$failedKey>')
      .when('the trigger is resolved')
      .then('it is <$triggerKey>')
      // No latch: page 0 is a cold load, any later page is scroll-driven.
      .example(
        val(pageKey, 0),
        val(pendingKey, null),
        val(failedKey, null),
        val(triggerKey, FetchTrigger.initialLoad),
      )
      .example(
        val(pageKey, 3),
        val(pendingKey, null),
        val(failedKey, null),
        val(triggerKey, FetchTrigger.nextPage),
      )
      // The page whose last attempt threw is a retry, first page included.
      .example(
        val(pageKey, 2),
        val(pendingKey, null),
        val(failedKey, 2),
        val(triggerKey, FetchTrigger.retry),
      )
      .example(
        val(pageKey, 0),
        val(pendingKey, null),
        val(failedKey, 0),
        val(triggerKey, FetchTrigger.retry),
      )
      // A failure on another page leaves this one alone.
      .example(
        val(pageKey, 3),
        val(pendingKey, null),
        val(failedKey, 1),
        val(triggerKey, FetchTrigger.nextPage),
      )
      // A latched trigger wins over both derivations, retry included.
      .example(
        val(pageKey, 0),
        val(pendingKey, FetchTrigger.refresh),
        val(failedKey, null),
        val(triggerKey, FetchTrigger.refresh),
      )
      .example(
        val(pageKey, 0),
        val(pendingKey, FetchTrigger.queryChanged),
        val(failedKey, 0),
        val(triggerKey, FetchTrigger.queryChanged),
      )
      .run((ctx) {
        final trigger = resolveTrigger(
          pageIndex: ctx.example.val(pageKey) as int,
          pending: ctx.example.val(pendingKey) as FetchTrigger?,
          lastFailedPageIndex: ctx.example.val(failedKey) as int?,
        );

        check(trigger).equals(ctx.example.val(triggerKey) as FetchTrigger);
      });
}

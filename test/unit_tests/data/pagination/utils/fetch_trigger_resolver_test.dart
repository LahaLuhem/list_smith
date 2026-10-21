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
      // Nothing pending: page 0 is a cold load, any later page is scroll-driven.
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
      // The page whose last attempt threw is a retry, 1st page included.
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
      // A pending trigger wins over both derivations, retry included.
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
      .run((context) {
        final trigger = resolveTrigger(
          pageIndex: context.example.val(pageKey) as int,
          pending: context.example.val(pendingKey) as FetchTrigger?,
          lastFailedPageIndex: context.example.val(failedKey) as int?,
        );

        check(trigger).equals(context.example.val(triggerKey) as FetchTrigger);
      });

  Bdd(triggerResolutionFeature)
      .scenario('a page read again because rows above it went reports invalidated')
      .given('page <$pageKey>, read again, and a last-failed <$failedKey>')
      .when('the trigger is resolved')
      .then('it is <$triggerKey>')
      .example(val(pageKey, 2), val(failedKey, null), val(triggerKey, FetchTrigger.invalidated))
      .example(val(pageKey, 0), val(failedKey, null), val(triggerKey, FetchTrigger.invalidated))
      // A retry outranks it.
      .example(val(pageKey, 2), val(failedKey, 2), val(triggerKey, FetchTrigger.retry))
      .run((context) {
        final trigger = resolveTrigger(
          pageIndex: context.example.val(pageKey) as int,
          pending: null,
          lastFailedPageIndex: context.example.val(failedKey) as int?,
          isReread: true,
        );

        check(trigger).equals(context.example.val(triggerKey) as FetchTrigger);
      });
}

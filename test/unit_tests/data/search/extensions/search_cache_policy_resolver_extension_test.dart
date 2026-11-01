import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:list_smith/src/data/search/search.dart';

void main() {
  final cacheTransitionFeature = BddFeature('Search cache transition');

  const policyKey = 'policy';
  const wasKey = 'wasSearching';
  const isKey = 'isSearching';
  const actionKey = 'action';

  Bdd(cacheTransitionFeature)
      .scenario('maps a mode transition to the cache action for the policy')
      .given('a <$policyKey> and a transition from wasSearching <$wasKey> to isSearching <$isKey>')
      .when('it resolves the cache action')
      .then('the action is <$actionKey>')
      // Replace keeps nothing on entering search.
      .example(
        val(policyKey, const ReplaceCachePolicy()),
        val(wasKey, false),
        val(isKey, true),
        val(actionKey, CacheAction.refresh),
      )
      // Keep reloads a search-to-search change, and leaves the feed it kept alone.
      .example(
        val(policyKey, const KeepCachePolicy()),
        val(wasKey, true),
        val(isKey, true),
        val(actionKey, CacheAction.refresh),
      )
      .run((context) {
        final action = (context.example.val(policyKey) as SearchCachePolicy).actionFor(
          wasSearching: context.example.val(wasKey) as bool,
          isSearching: context.example.val(isKey) as bool,
        );

        check(action).equals(context.example.val(actionKey) as CacheAction);
      });
}

import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:list_smith/list_smith.dart';
import 'package:list_smith/src/data/search/search_cache_policy_resolver.dart';

void main() {
  final cacheTransition = BddFeature('Search cache transition');

  const policyKey = 'policy';
  const wasKey = 'wasSearching';
  const isKey = 'isSearching';
  const actionKey = 'action';
  Bdd(cacheTransition)
      .scenario('maps a mode transition to the cache action for the policy')
      .given('a <$policyKey> and a transition from wasSearching <$wasKey> to isSearching <$isKey>')
      .when('it resolves the cache action')
      .then('the action is <$actionKey>')
      // Replace reloads clean whichever way the mode moves.
      .example(
        val(policyKey, const ReplaceCachePolicy()),
        val(wasKey, false),
        val(isKey, true),
        val(actionKey, CacheAction.refresh),
      )
      .example(
        val(policyKey, const ReplaceCachePolicy()),
        val(wasKey, true),
        val(isKey, false),
        val(actionKey, CacheAction.refresh),
      )
      .example(
        val(policyKey, const ReplaceCachePolicy()),
        val(wasKey, true),
        val(isKey, true),
        val(actionKey, CacheAction.refresh),
      )
      // Keep snapshots on entering search, restores on leaving, and reloads a search-to-search change.
      .example(
        val(policyKey, const KeepCachePolicy()),
        val(wasKey, false),
        val(isKey, true),
        val(actionKey, CacheAction.snapshotThenRefresh),
      )
      .example(
        val(policyKey, const KeepCachePolicy()),
        val(wasKey, true),
        val(isKey, false),
        val(actionKey, CacheAction.restoreNormal),
      )
      .example(
        val(policyKey, const KeepCachePolicy()),
        val(wasKey, true),
        val(isKey, true),
        val(actionKey, CacheAction.refresh),
      )
      .run((ctx) {
        final action = (ctx.example.val(policyKey) as SearchCachePolicy).actionFor(
          wasSearching: ctx.example.val(wasKey) as bool,
          isSearching: ctx.example.val(isKey) as bool,
        );

        check(action).equals(ctx.example.val(actionKey) as CacheAction);
      });
}

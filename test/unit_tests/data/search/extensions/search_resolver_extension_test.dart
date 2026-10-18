import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:list_smith/list_smith.dart';
import 'package:list_smith/src/data/search/enums/cache_action.dart';
import 'package:list_smith/src/data/search/extensions/search_resolver_extension.dart';

void main() {
  final searchTransitionFeature = BddFeature('Search mode transition');

  Bdd(searchTransitionFeature)
      .scenario('search taken away lands on the kept feed')
      .given('a list with no search')
      .when('it leaves search mode')
      .then('it restores the feed')
      .run((_) {
        final action = const NoSearch().cacheActionFor(wasSearching: true, isSearching: false);

        check(action).equals(CacheAction.restoreNormal);
      });

  Bdd(searchTransitionFeature)
      .scenario('an async search does what its cache policy says')
      .given('an async search that keeps the feed')
      .when('it enters search mode')
      .then('it parks the feed')
      .run((_) {
        final search = AsyncSearch<int>(
          fetchPage: SearchPageFetcher((_) async => const []),
          cachePolicy: const KeepCachePolicy(),
        );

        final action = search.cacheActionFor(wasSearching: false, isSearching: true);

        check(action).equals(CacheAction.snapshotThenRefresh);
      });
}

import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:list_smith/src/data/search/search.dart';

void main() {
  final syncSearchFeature = BddFeature('Sync search resolution');

  const items = ['apple', 'banana', 'cherry'];
  bool contains(String item, String query) => item.toLowerCase().contains(query.toLowerCase());

  const queryKey = 'query';
  const searchingKey = 'searching';
  const visibleKey = 'visible';

  Bdd(syncSearchFeature)
      .scenario(
        'shows everything for an empty committed query, and filters by the predicate otherwise',
      )
      .given('items $items and a case-insensitive contains predicate')
      .when('it resolves the committed query <$queryKey>')
      .then('isSearching is <$searchingKey> and the visible items are <$visibleKey>')
      .example(val(queryKey, ''), val(searchingKey, false), val(visibleKey, items))
      .example(
        val(queryKey, 'a'),
        val(searchingKey, true),
        val(visibleKey, const ['apple', 'banana']),
      )
      // A miss yields an empty, no-results list.
      .example(val(queryKey, 'xyz'), val(searchingKey, true), val(visibleKey, const <String>[]))
      .run((context) {
        final searchResult = resolveSyncSearch(
          items,
          contains,
          context.example.val(queryKey) as String,
        );

        check(searchResult.isSearching).equals(context.example.val(searchingKey) as bool);
        check(searchResult.visibleItems)
            .deepEquals(context.example.val(visibleKey) as List<String>);
      });
}

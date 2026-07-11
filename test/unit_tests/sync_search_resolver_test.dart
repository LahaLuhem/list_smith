import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:list_smith/src/data/search/utils/sync_search_resolver.dart';

void main() {
  final syncSearch = BddFeature('Sync search resolution');

  const items = ['apple', 'banana', 'cherry'];
  bool contains(String item, String query) => item.toLowerCase().contains(query.toLowerCase());

  const queryKey = 'query';
  const minLengthKey = 'minLength';
  const searchingKey = 'searching';
  const visibleKey = 'visible';
  Bdd(syncSearch)
      .scenario('gates the query by trim and min-length, then filters by the predicate')
      .given('items ["apple", "banana", "cherry"] and a case-insensitive contains predicate')
      .when('it resolves query <$queryKey> with minSearchLength <$minLengthKey>')
      .then('isSearching is <$searchingKey> and the visible items are <$visibleKey>')
      // Empty or too-short queries count as no search: every item stays visible.
      .example(
        val(queryKey, ''),
        val(minLengthKey, 0),
        val(searchingKey, false),
        val(visibleKey, items),
      )
      .example(
        val(queryKey, '  '),
        val(minLengthKey, 0),
        val(searchingKey, false),
        val(visibleKey, items),
      )
      .example(
        val(queryKey, 'ap'),
        val(minLengthKey, 3),
        val(searchingKey, false),
        val(visibleKey, items),
      )
      // Active searches filter (trimming first); a miss yields an empty, no-results list.
      .example(
        val(queryKey, 'a'),
        val(minLengthKey, 0),
        val(searchingKey, true),
        val(visibleKey, const ['apple', 'banana']),
      )
      .example(
        val(queryKey, ' a '),
        val(minLengthKey, 0),
        val(searchingKey, true),
        val(visibleKey, const ['apple', 'banana']),
      )
      .example(
        val(queryKey, 'app'),
        val(minLengthKey, 3),
        val(searchingKey, true),
        val(visibleKey, const ['apple']),
      )
      .example(
        val(queryKey, 'xyz'),
        val(minLengthKey, 0),
        val(searchingKey, true),
        val(visibleKey, const <String>[]),
      )
      .run((ctx) {
        final result = resolveSyncSearch(
          items,
          contains,
          ctx.example.val(queryKey) as String,
          ctx.example.val(minLengthKey) as int,
        );

        check(result.isSearching).equals(ctx.example.val(searchingKey) as bool);
        check(result.visibleItems).deepEquals(ctx.example.val(visibleKey) as List<String>);
      });
}

import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:list_smith/src/data/search/models/sync_search_predicates.dart';

typedef _City = ({String name, String? country});

void main() {
  final fieldsPredicate = BddFeature('SyncSearchPredicates.fields');

  const nameKey = 'name';
  const countryKey = 'country';
  const queryKey = 'query';
  const matchesKey = 'matches';

  Bdd(fieldsPredicate)
      .scenario('keeps an item when any field contains the query, case-insensitively')
      .given('a predicate over an item name and a nullable country')
      .when('it tests an item <$nameKey>/<$countryKey> against query <$queryKey>')
      .then('the match result is <$matchesKey>')
      // Case-insensitive in both directions: field lower-cased and query lower-cased.
      .example(
        val(nameKey, 'Paris'),
        val(countryKey, 'France'),
        val(queryKey, 'par'),
        val(matchesKey, true),
      )
      .example(
        val(nameKey, 'Paris'),
        val(countryKey, 'France'),
        val(queryKey, 'PAR'),
        val(matchesKey, true),
      )
      // Any field can match, not only the first.
      .example(
        val(nameKey, 'Paris'),
        val(countryKey, 'France'),
        val(queryKey, 'ance'),
        val(matchesKey, true),
      )
      // No field contains the query: a miss.
      .example(
        val(nameKey, 'Paris'),
        val(countryKey, 'France'),
        val(queryKey, 'xyz'),
        val(matchesKey, false),
      )
      // A null field is skipped: it neither throws nor matches; other fields still count.
      .example(
        val(nameKey, 'Paris'),
        val(countryKey, null),
        val(queryKey, 'par'),
        val(matchesKey, true),
      )
      .example(
        val(nameKey, 'Paris'),
        val(countryKey, null),
        val(queryKey, 'ance'),
        val(matchesKey, false),
      )
      .run((ctx) {
        final searchBy = SyncSearchPredicates.fields<_City>([
          (city) => city.name,
          (city) => city.country,
        ]);
        final city = (
          name: ctx.example.val(nameKey) as String,
          country: ctx.example.val(countryKey) as String?,
        );

        check(
          searchBy(city, ctx.example.val(queryKey) as String),
        ).equals(ctx.example.val(matchesKey) as bool);
      });

  Bdd(fieldsPredicate)
      .scenario('rejects an empty extractor list at construction')
      .given('no field extractors')
      .when('a predicate is built')
      .then('it fails an assertion')
      .run((_) {
        check(() => SyncSearchPredicates.fields<String>(const [])).throws<AssertionError>();
      });
}

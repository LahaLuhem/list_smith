import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:list_smith/src/data/search/models/sync_search_predicates.dart';

typedef _City = ({String name, String? country});

void main() {
  final predicates = BddFeature('SyncSearchPredicates');

  const nameKey = 'name';
  const countryKey = 'country';
  const queryKey = 'query';
  const matchesKey = 'matches';

  Bdd(predicates)
      .scenario('fields keeps an item when any field contains the query, case-insensitively')
      .given('a fields predicate over an item name and a nullable country')
      .when('it tests an item <$nameKey>/<$countryKey> against query <$queryKey>')
      .then('the match result is <$matchesKey>')
      // Case-insensitive in both directions.
      .example(
        val(nameKey, 'Paris'),
        val(countryKey, 'France'),
        val(queryKey, 'ar'),
        val(matchesKey, true),
      )
      .example(
        val(nameKey, 'Paris'),
        val(countryKey, 'France'),
        val(queryKey, 'AR'),
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
        val(queryKey, 'ar'),
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

        final item = (
          name: ctx.example.val(nameKey) as String,
          country: ctx.example.val(countryKey) as String?,
        );

        check(
          searchBy(item, ctx.example.val(queryKey) as String),
        ).equals(ctx.example.val(matchesKey) as bool);
      });

  Bdd(predicates)
      .scenario('prefix keeps an item when any field starts with the query, case-insensitively')
      .given('a prefix predicate over an item name and a nullable country')
      .when('it tests an item <$nameKey>/<$countryKey> against query <$queryKey>')
      .then('the match result is <$matchesKey>')
      // A prefix hit, case-insensitive.
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
      // A mid-string match is not a prefix: a miss.
      .example(
        val(nameKey, 'Paris'),
        val(countryKey, 'France'),
        val(queryKey, 'ris'),
        val(matchesKey, false),
      )
      // Another field's prefix still counts.
      .example(
        val(nameKey, 'Paris'),
        val(countryKey, 'France'),
        val(queryKey, 'fra'),
        val(matchesKey, true),
      )
      // Null field skipped.
      .example(
        val(nameKey, 'Paris'),
        val(countryKey, null),
        val(queryKey, 'par'),
        val(matchesKey, true),
      )
      .example(
        val(nameKey, 'Paris'),
        val(countryKey, null),
        val(queryKey, 'fra'),
        val(matchesKey, false),
      )
      .run((ctx) {
        final searchBy = SyncSearchPredicates.prefix<_City>([
          (city) => city.name,
          (city) => city.country,
        ]);

        final item = (
          name: ctx.example.val(nameKey) as String,
          country: ctx.example.val(countryKey) as String?,
        );

        check(
          searchBy(item, ctx.example.val(queryKey) as String),
        ).equals(ctx.example.val(matchesKey) as bool);
      });

  Bdd(predicates)
      .scenario('exact keeps an item only on a full, case-insensitive field equality')
      .given('an exact predicate over an item name and a nullable country')
      .when('it tests an item <$nameKey>/<$countryKey> against query <$queryKey>')
      .then('the match result is <$matchesKey>')
      // Full-value equality, case-insensitive.
      .example(
        val(nameKey, 'Paris'),
        val(countryKey, 'France'),
        val(queryKey, 'paris'),
        val(matchesKey, true),
      )
      .example(
        val(nameKey, 'Paris'),
        val(countryKey, 'France'),
        val(queryKey, 'PARIS'),
        val(matchesKey, true),
      )
      // A prefix or substring is not enough: a miss.
      .example(
        val(nameKey, 'Paris'),
        val(countryKey, 'France'),
        val(queryKey, 'par'),
        val(matchesKey, false),
      )
      // Another field's full value still counts.
      .example(
        val(nameKey, 'Paris'),
        val(countryKey, 'France'),
        val(queryKey, 'france'),
        val(matchesKey, true),
      )
      // Null field skipped.
      .example(
        val(nameKey, 'Paris'),
        val(countryKey, null),
        val(queryKey, 'paris'),
        val(matchesKey, true),
      )
      .example(
        val(nameKey, 'Paris'),
        val(countryKey, null),
        val(queryKey, 'france'),
        val(matchesKey, false),
      )
      .run((ctx) {
        final searchBy = SyncSearchPredicates.exact<_City>([
          (city) => city.name,
          (city) => city.country,
        ]);

        final item = (
          name: ctx.example.val(nameKey) as String,
          country: ctx.example.val(countryKey) as String?,
        );

        check(
          searchBy(item, ctx.example.val(queryKey) as String),
        ).equals(ctx.example.val(matchesKey) as bool);
      });

  Bdd(predicates)
      .scenario('allTerms requires every whitespace term to hit some field, in any order')
      .given('an allTerms predicate over an item name and a nullable country')
      .when('it tests an item <$nameKey>/<$countryKey> against query <$queryKey>')
      .then('the match result is <$matchesKey>')
      // Both terms in one field.
      .example(
        val(nameKey, 'John Smith'),
        val(countryKey, 'USA'),
        val(queryKey, 'john smith'),
        val(matchesKey, true),
      )
      // Order-independent.
      .example(
        val(nameKey, 'John Smith'),
        val(countryKey, 'USA'),
        val(queryKey, 'smith john'),
        val(matchesKey, true),
      )
      // Terms may match across different fields.
      .example(
        val(nameKey, 'John Smith'),
        val(countryKey, 'USA'),
        val(queryKey, 'john usa'),
        val(matchesKey, true),
      )
      // One term absent everywhere: a miss.
      .example(
        val(nameKey, 'John Smith'),
        val(countryKey, 'USA'),
        val(queryKey, 'john paris'),
        val(matchesKey, false),
      )
      // A single term behaves exactly like fields (contains).
      .example(
        val(nameKey, 'John Smith'),
        val(countryKey, 'USA'),
        val(queryKey, 'smith'),
        val(matchesKey, true),
      )
      // A term only in a null field can't be found.
      .example(
        val(nameKey, 'John Smith'),
        val(countryKey, null),
        val(queryKey, 'john usa'),
        val(matchesKey, false),
      )
      .run((ctx) {
        final searchBy = SyncSearchPredicates.allTerms<_City>([
          (city) => city.name,
          (city) => city.country,
        ]);

        final item = (
          name: ctx.example.val(nameKey) as String,
          country: ctx.example.val(countryKey) as String?,
        );

        check(
          searchBy(item, ctx.example.val(queryKey) as String),
        ).equals(ctx.example.val(matchesKey) as bool);
      });

  Bdd(predicates)
      .scenario('any matches when at least one combined predicate matches')
      .given('any of a name-prefix predicate or an exact-country predicate')
      .when('it tests a Paris/France item against query <$queryKey>')
      .then('the match result is <$matchesKey>')
      // The name-prefix arm matches.
      .example(val(queryKey, 'par'), val(matchesKey, true))
      // The exact-country arm matches.
      .example(val(queryKey, 'france'), val(matchesKey, true))
      // Neither arm matches.
      .example(val(queryKey, 'xyz'), val(matchesKey, false))
      .run((ctx) {
        final searchBy = SyncSearchPredicates.any<_City>([
          SyncSearchPredicates.prefix([(city) => city.name]),
          SyncSearchPredicates.exact([(city) => city.country]),
        ]);

        check(
          searchBy((name: 'Paris', country: 'France'), ctx.example.val(queryKey) as String),
        ).equals(ctx.example.val(matchesKey) as bool);
      });

  Bdd(predicates)
      .scenario('every matches only when all combined predicates match')
      .given('every of a name-contains predicate and a country-contains predicate')
      .when('it tests an item <$nameKey>/<$countryKey> against query <$queryKey>')
      .then('the match result is <$matchesKey>')
      // The query is in both fields.
      .example(
        val(nameKey, 'Paris'),
        val(countryKey, 'Paris'),
        val(queryKey, 'par'),
        val(matchesKey, true),
      )
      // The query is in one field only: a miss.
      .example(
        val(nameKey, 'Paris'),
        val(countryKey, 'France'),
        val(queryKey, 'par'),
        val(matchesKey, false),
      )
      // In neither: a miss.
      .example(
        val(nameKey, 'Paris'),
        val(countryKey, 'France'),
        val(queryKey, 'xyz'),
        val(matchesKey, false),
      )
      .run((ctx) {
        final searchBy = SyncSearchPredicates.every<_City>([
          SyncSearchPredicates.fields([(city) => city.name]),
          SyncSearchPredicates.fields([(city) => city.country]),
        ]);

        final item = (
          name: ctx.example.val(nameKey) as String,
          country: ctx.example.val(countryKey) as String?,
        );

        check(
          searchBy(item, ctx.example.val(queryKey) as String),
        ).equals(ctx.example.val(matchesKey) as bool);
      });

  Bdd(predicates)
      .scenario('every builder rejects empty input at construction')
      .given('no extractors or predicates')
      .when('a builder is called')
      .then('it fails an assertion')
      .run((_) {
        check(() => SyncSearchPredicates.fields<String>(const [])).throws<AssertionError>();
        check(() => SyncSearchPredicates.prefix<String>(const [])).throws<AssertionError>();
        check(() => SyncSearchPredicates.exact<String>(const [])).throws<AssertionError>();
        check(() => SyncSearchPredicates.allTerms<String>(const [])).throws<AssertionError>();
        check(() => SyncSearchPredicates.any<String>(const [])).throws<AssertionError>();
        check(() => SyncSearchPredicates.every<String>(const [])).throws<AssertionError>();
      });
}

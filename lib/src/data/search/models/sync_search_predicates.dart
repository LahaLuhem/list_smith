/// @docImport '/src/widgets/list_smith.dart';
library;

import '../typedefs/sync_search_predicate.dart';

/// Ready-made [SyncSearchPredicate] builders for the usual shapes, built from field extractors.
///
/// [fields] (contains), [prefix] (starts with), [exact] (equals), [allTerms] (every word has to hit
/// some field), plus [any] and [every] to combine them. All case-insensitive, all skipping `null` fields,
/// all needing at least 1 extractor. Anything past these is a hand-written [ListSmith.sync] `searchBy`.
///
/// Pin the item type on the list, `ListSmith<City>.sync(...)`. Inline, the list's element type and a
/// builder's type parameter resolve together and the extractor closures come out nullable. Naming it
/// once covers every builder.
abstract final class SyncSearchPredicates {
  /// Keeps an item when any field from [extractors] *contains* the query, case-insensitively.
  ///
  /// What nearly every sync list wants. A `null` field never matches, so nullable fields need no `??
  /// ''`.
  ///
  /// ```dart
  /// ListSmith<City>.sync(
  ///   items: cities,
  ///   searchBy: SyncSearchPredicates.fields([(city) => city.name, (city) => city.country]),
  ///   itemBuilder: (context, city, index) => Text(city.name),
  /// )
  /// ```
  static SyncSearchPredicate<T> fields<T extends Object>(
    Iterable<String? Function(T item)> extractors,
  ) => _anyField(extractors, (value, query) => value.contains(query));

  /// Like [fields], but anchored to the start of the field, for type-ahead.
  static SyncSearchPredicate<T> prefix<T extends Object>(
    Iterable<String? Function(T item)> extractors,
  ) => _anyField(extractors, (value, query) => value.startsWith(query));

  /// Like [fields], but a whole-value match, for filtering rather than search-as-you-type.
  static SyncSearchPredicate<T> exact<T extends Object>(
    Iterable<String? Function(T item)> extractors,
  ) => _anyField(extractors, (value, query) => value == query);

  /// Keeps an item when *every* word in the query hits some field from [extractors]. Words can match
  /// across different fields.
  ///
  /// For multi-word queries: `'john smith'` hits an item holding `'Smith, John'`, where [fields] wouldn't.
  /// One word behaves exactly like [fields].
  static SyncSearchPredicate<T> allTerms<T extends Object>(
    Iterable<String? Function(T item)> extractors,
  ) {
    final fieldExtractors = extractors.toList(growable: false);
    assert(fieldExtractors.isNotEmpty, 'Pass at least one field extractor to match against.');

    return (item, query) {
      final terms = query.toLowerCase().split(' ').where((term) => term.isNotEmpty);
      final fieldValues = fieldExtractors
          .map((extractField) => extractField(item))
          .nonNulls
          .map((value) => value.toLowerCase())
          .toList(growable: false);

      return terms.every((term) => fieldValues.any((value) => value.contains(term)));
    };
  }

  /// Matches when *any* of [predicates] matches. Each gets the same item and query.
  static SyncSearchPredicate<T> any<T extends Object>(Iterable<SyncSearchPredicate<T>> predicates) {
    final options = predicates.toList(growable: false);
    assert(options.isNotEmpty, 'Pass at least one predicate to combine.');

    return (item, query) => options.any((predicate) => predicate(item, query));
  }

  /// Matches only when *every* one of [predicates] matches. Each gets the same item and query.
  static SyncSearchPredicate<T> every<T extends Object>(
    Iterable<SyncSearchPredicate<T>> predicates,
  ) {
    final requirements = predicates.toList(growable: false);
    assert(requirements.isNotEmpty, 'Pass at least one predicate to combine.');

    return (item, query) => requirements.every((predicate) => predicate(item, query));
  }

  // Keeps an item when `test` holds for any extracted field against the query, both lower-cased.
  static SyncSearchPredicate<T> _anyField<T extends Object>(
    Iterable<String? Function(T item)> extractors,
    bool Function(String value, String query) test,
  ) {
    final fieldExtractors = extractors.toList(growable: false);
    assert(fieldExtractors.isNotEmpty, 'Pass at least one field extractor to match against.');

    return (item, query) {
      final lowerQuery = query.toLowerCase();

      return fieldExtractors
          .map((extractField) => extractField(item))
          .nonNulls
          .any((value) => test(value.toLowerCase(), lowerQuery));
    };
  }
}

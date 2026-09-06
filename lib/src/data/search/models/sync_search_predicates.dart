/// @docImport '/src/widgets/list_smith.dart';
library;

import '../typedefs/sync_search_predicate.dart';

/// Ready-made [SyncSearchPredicate] builders for the usual sync-search shapes, built from a list of
/// field extractors.
///
/// [fields] (contains), [prefix] (starts with), [exact] (equals), [allTerms] (every whitespace term
/// must hit a field), plus [any] and [every] to combine them. All case-insensitive, all skipping
/// `null` fields. Anything past them is a hand-written [ListSmith.sync] `searchBy`.
///
/// Pin the item type on the list, `ListSmith<City>.sync(...)`. Used inline, the list's element type
/// and a builder's type parameter resolve together and the extractor closures come out nullable
/// otherwise. Naming it once covers every builder.
abstract final class SyncSearchPredicates {
  /// Keeps an item when any field from [extractors] *contains* the query, case-insensitively.
  ///
  /// The shape nearly every sync list wants. Each extractor pulls one field off an item, and a
  /// `null` field never matches, so nullable fields need no `?? ''`. Pass at least one extractor.
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

  /// Keeps an item when any field from [extractors] *starts with* the query, case-insensitively.
  ///
  /// Like [fields], but prefix-anchored, for type-ahead. Pass at least one extractor.
  static SyncSearchPredicate<T> prefix<T extends Object>(
    Iterable<String? Function(T item)> extractors,
  ) => _anyField(extractors, (value, query) => value.startsWith(query));

  /// Keeps an item when any field from [extractors] *equals* the query, case-insensitively.
  ///
  /// Like [fields], but a full-value match, for filtering rather than search-as-you-type. Pass at
  /// least one extractor.
  static SyncSearchPredicate<T> exact<T extends Object>(
    Iterable<String? Function(T item)> extractors,
  ) => _anyField(extractors, (value, query) => value == query);

  /// Keeps an item when *every* whitespace-separated term in the query hits some field from
  /// [extractors] (each term a case-insensitive substring), the terms matching across any fields.
  ///
  /// For multi-word queries: `'john smith'` hits an item holding `'Smith, John'`, where [fields]
  /// wouldn't. One term behaves exactly like [fields]. Pass at least one extractor.
  static SyncSearchPredicate<T> allTerms<T extends Object>(
    Iterable<String? Function(T item)> extractors,
  ) {
    final fieldExtractors = extractors.toList(growable: false);
    assert(fieldExtractors.isNotEmpty, 'Pass at least one field extractor to match against.');

    return (item, query) {
      final terms = query.toLowerCase().split(' ').where((term) => term.isNotEmpty);
      final values = fieldExtractors
          .map((extractField) => extractField(item))
          .nonNulls
          .map((value) => value.toLowerCase())
          .toList(growable: false);

      return terms.every((term) => values.any((value) => value.contains(term)));
    };
  }

  /// A predicate that matches when *any* of [predicates] matches (logical OR).
  ///
  /// Each gets the same item and query. Pass at least one.
  static SyncSearchPredicate<T> any<T extends Object>(Iterable<SyncSearchPredicate<T>> predicates) {
    final options = predicates.toList(growable: false);
    assert(options.isNotEmpty, 'Pass at least one predicate to combine.');

    return (item, query) => options.any((predicate) => predicate(item, query));
  }

  /// A predicate that matches only when *every* one of [predicates] matches (logical AND).
  ///
  /// Each gets the same item and query. Pass at least one.
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

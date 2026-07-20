/// @docImport '/src/widgets/list_smith.dart';
library;

import '../typedefs/sync_search_predicate.dart';

/// Ready-made [SyncSearchPredicate] builders for the common sync-search cases.
///
/// [ListSmith.sync] takes a raw [SyncSearchPredicate] so the consumer owns matching entirely (case,
/// diacritics, fuzzy, and so on). Most lists want one of a few shapes though, so this namespace builds
/// them from a list of field extractors: [fields] (contains), [prefix] (starts with), [exact] (equals),
/// and [allTerms] (every whitespace-separated term must hit a field), plus [any] and [every] to combine
/// predicates. Each field builder is case-insensitive and skips `null` fields; anything beyond them
/// drops back to a hand-written `searchBy`.
///
/// Pin the item type on the list, `ListSmith<City>.sync(...)`, when it cannot be inferred: used inline,
/// the list's element type and a builder's type parameter resolve together, and the un-annotated
/// extractor closures would otherwise come out nullable. Naming it once on the list covers every
/// builder passed.
abstract final class SyncSearchPredicates {
  /// Keeps an item when any field from [extractors] *contains* the query, case-insensitively.
  ///
  /// The shape nearly every sync list wants. Each extractor pulls one field off an item; a `null`
  /// field is skipped (it never matches), so nullable fields need no `?? ''`. The query arrives trimmed
  /// and past the min-length gate, so no field matches an empty query. Pass at least one extractor. For
  /// case-sensitive, diacritic-folded, or fuzzy matching, write the [SyncSearchPredicate] directly.
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
  /// Like [fields], but prefix-anchored, for type-ahead and autocomplete. `null` fields are skipped;
  /// pass at least one extractor.
  static SyncSearchPredicate<T> prefix<T extends Object>(
    Iterable<String? Function(T item)> extractors,
  ) => _anyField(extractors, (value, query) => value.startsWith(query));

  /// Keeps an item when any field from [extractors] *equals* the query, case-insensitively.
  ///
  /// Like [fields], but a full-value match, for filtering by an exact value rather than
  /// search-as-you-type. `null` fields are skipped; pass at least one extractor.
  static SyncSearchPredicate<T> exact<T extends Object>(
    Iterable<String? Function(T item)> extractors,
  ) => _anyField(extractors, (value, query) => value == query);

  /// Keeps an item when *every* whitespace-separated term in the query hits some field from
  /// [extractors] (each term a case-insensitive substring), the terms matching across any fields.
  ///
  /// Handles multi-word queries: `'john smith'` matches an item whose fields hold `'Smith, John'`,
  /// where [fields] (a single substring) would not. A single-term query behaves exactly like [fields].
  /// `null` fields are skipped; pass at least one extractor.
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
  /// Combines built or hand-written [SyncSearchPredicate]s, e.g. match by fields or a bespoke rule.
  /// Each receives the same item and query. Pass at least one predicate.
  static SyncSearchPredicate<T> any<T extends Object>(Iterable<SyncSearchPredicate<T>> predicates) {
    final options = predicates.toList(growable: false);
    assert(options.isNotEmpty, 'Pass at least one predicate to combine.');

    return (item, query) => options.any((predicate) => predicate(item, query));
  }

  /// A predicate that matches only when *every* one of [predicates] matches (logical AND).
  ///
  /// Combines built or hand-written [SyncSearchPredicate]s, all receiving the same item and query.
  /// Pass at least one predicate.
  static SyncSearchPredicate<T> every<T extends Object>(
    Iterable<SyncSearchPredicate<T>> predicates,
  ) {
    final requirements = predicates.toList(growable: false);
    assert(requirements.isNotEmpty, 'Pass at least one predicate to combine.');

    return (item, query) => requirements.every((predicate) => predicate(item, query));
  }

  // Builds a field predicate: keeps an item when [test] holds for any extracted field against the
  // query, both lower-cased. Shared by [fields], [prefix], and [exact].
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

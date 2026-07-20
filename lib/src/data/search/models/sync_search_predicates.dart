/// @docImport '/src/widgets/list_smith.dart';
library;

import '../typedefs/sync_search_predicate.dart';

/// Ready-made [SyncSearchPredicate] builders for the common sync-search cases.
///
/// [ListSmith.sync] takes a raw [SyncSearchPredicate] so the consumer owns matching entirely (case,
/// diacritics, fuzzy, prefix, and so on). Most lists want the same shape though: keep an item when any
/// of its text fields contains the query. This namespace builds that predicate from a list of field
/// extractors, so a consumer configures *which* fields to search instead of re-implementing the
/// case-insensitive substring loop. Anything beyond the common shape drops back to a hand-written
/// `searchBy`.
abstract final class SyncSearchPredicates {
  /// A predicate that keeps an item when any field from [extractors] contains the query.
  ///
  /// Matching is case-insensitive substring (`toLowerCase().contains`), the shape nearly every sync
  /// list wants. Each extractor pulls one field off an item; a `null` field is skipped (it never
  /// matches), so nullable fields need no `?? ''`. The query arrives trimmed and past the min-length
  /// gate, so no field matches an empty query (a non-searching list shows every item anyway). Pass at
  /// least one extractor.
  ///
  /// For case-sensitive, diacritic-folded, fuzzy, or tokenised matching, write the [SyncSearchPredicate]
  /// directly instead; this builder deliberately bakes in only the common policy.
  ///
  /// Name the item type when it cannot be inferred, which is the usual inline case inside
  /// `ListSmith.sync(searchBy: ...)` (the list's element type and this builder's type resolve
  /// together): `SyncSearchPredicates.fields<City>([...])`.
  ///
  /// ```dart
  /// ListSmith.sync(
  ///   items: cities,
  ///   searchBy: SyncSearchPredicates.fields<City>([(city) => city.name, (city) => city.country]),
  ///   itemBuilder: (context, city, index) => Text(city.name),
  /// )
  /// ```
  static SyncSearchPredicate<T> fields<T extends Object>(
    Iterable<String? Function(T item)> extractors,
  ) {
    final fieldExtractors = extractors.toList(growable: false);
    assert(fieldExtractors.isNotEmpty, 'Pass at least one field extractor to match against.');

    return (item, query) {
      final lowerQuery = query.toLowerCase();

      return fieldExtractors
          .map((extractField) => extractField(item))
          .nonNulls
          .any((value) => value.toLowerCase().contains(lowerQuery));
    };
  }
}

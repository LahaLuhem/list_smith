import '../typedefs/sync_search_predicate.dart';

/// Applies a sync search over [items]: what is visible for [query], and whether a search is active
/// at all, so the caller can pick the no-results surface over the plain list.
///
/// [query] is trimmed. Empty, or shorter than [minSearchLength], counts as no search: everything
/// stays visible and `isSearching` is `false`. Visible items come back lazy, for the caller to
/// materialise once.
({Iterable<T> visibleItems, bool isSearching}) resolveSyncSearch<T extends Object>(
  List<T> items,
  SyncSearchPredicate<T> searchBy,
  String query,
  int minSearchLength,
) {
  final trimmedQuery = query.trim();
  final isSearching = trimmedQuery.isNotEmpty && trimmedQuery.length >= minSearchLength;
  if (!isSearching) return (visibleItems: items, isSearching: false);

  final visibleItems = items.where((item) => searchBy(item, trimmedQuery));

  return (visibleItems: visibleItems, isSearching: true);
}

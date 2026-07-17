import '../typedefs/sync_search_predicate.dart';

/// Applies a sync search over [items]: which items are visible for [query], and whether a search is
/// actually active (so the caller can show the no-results surface instead of the plain list).
///
/// [query] is trimmed; when the trimmed query is empty or shorter than [minSearchLength] it counts
/// as no search, so every item stays visible and `isSearching` is `false`. Kept widget-free and pure
/// so the gating and filtering are unit-tested directly, without pumping a widget
/// (as `PaginationEndPolicy.hasReachedEnd` is). The visible items are returned as a lazy view, so the
/// caller materialises them once (directly, or by grouping them).
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

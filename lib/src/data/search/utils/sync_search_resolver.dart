import 'package:meta/meta.dart';

import '../typedefs/sync_search_predicate.dart';

/// Runs a sync search over [items]: what's visible for [query], and whether a search is on at all, so
/// the caller can pick the no-results surface over the plain list.
///
/// [query] is the committed one, already trimmed and gated by `QueryDebouncer`, so empty means no
/// search: everything stays visible and `isSearching` is `false`. Visible items come back lazy.
@internal
({Iterable<T> visibleItems, bool isSearching}) resolveSyncSearch<T extends Object>(
  List<T> items,
  SyncSearchPredicate<T> searchBy,
  String query,
) {
  if (query.isEmpty) return (visibleItems: items, isSearching: false);

  final visibleItems = items.where((item) => searchBy(item, query));

  return (visibleItems: visibleItems, isSearching: true);
}

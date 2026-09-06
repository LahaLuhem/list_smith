/// Decides whether an item matches a search query, for a sync (in-memory) list_smith list.
///
/// Returns `true` to keep `item` in the results for `query`, which arrives trimmed and past the
/// min-length gate. list_smith bakes in no case, diacritic, or field policy, so matching is entirely
/// yours. `SyncSearchPredicates` has the ready-made shapes.
typedef SyncSearchPredicate<T extends Object> = bool Function(T item, String query);

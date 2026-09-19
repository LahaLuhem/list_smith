/// Decides whether an item matches a query, for a sync (in-memory) list.
///
/// Return `true` to keep `item` in the results for `query`, which arrives trimmed and past the min-length
/// gate. Case, accents and which fields to look at are all yours. `SyncSearchPredicates` has the ready-made
/// shapes.
typedef SyncSearchPredicate<T extends Object> = bool Function(T item, String query);

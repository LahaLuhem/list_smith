/// Decides whether an item matches a search query, for a sync (in-memory) list_smith list.
///
/// Returns `true` to keep `item` in the results for `query`. This is the single matching primitive:
/// list_smith bakes in no case, diacritic, or field policy, so the consumer expresses exactly the
/// matching they want (case-insensitive contains, prefix, fuzzy, multi-field, and so on). `query`
/// arrives already trimmed and past the min-length gate.
typedef SyncSearchPredicate<T extends Object> = bool Function(T item, String query);

/// Extracts a stable identity key from an item, for de-duplicating paginated results.
///
/// Passed to `ListSmith.async` as `itemId`. When provided, each freshly-fetched page drops any item
/// whose key already appeared in the loaded list (or earlier in the same page) before it is shown, so
/// an offset-based source whose pages overlap at the boundary does not render the same item twice.
///
/// The key is compared by `==` / `hashCode`, so return something with value equality: an `int` or
/// `String` id, or a composite like `'${item.a}:${item.b}'` for multi-field identity. Null (the
/// default) means no de-duplication, matching the underlying `infinite_scroll_pagination` behaviour.
typedef ItemId<T extends Object> = Object Function(T item);

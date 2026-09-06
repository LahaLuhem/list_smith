/// Extracts a stable identity key from an item, for de-duplicating overlapping pages.
///
/// Passed to `ListSmith.async` as `itemId`. Any item whose key already appeared is dropped before it
/// renders, so an offset-based source whose pages overlap doesn't show a row twice. Keys compare by
/// `==` / `hashCode`, so use an `int`, a `String`, or a composite like `'${item.a}:${item.b}'`.
/// Null (the default) de-duplicates nothing.
typedef ItemId<T extends Object> = Object Function(T item);

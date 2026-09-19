/// Pulls a stable identity key off an item, so overlapping pages don't render a row twice.
///
/// Passed to `ListSmith.async` as `itemId`. Any item whose key already showed up is dropped before it
/// renders. Keys compare by `==` / `hashCode`, so an `int`, a `String`, or a composite like `'${item.a}:${item.b}'`.
/// Null (the default) de-duplicates nothing.
typedef ItemId<T extends Object> = Object Function(T item);

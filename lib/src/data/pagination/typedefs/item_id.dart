/// Pulls a stable identity key off an item. The list drops an item whose key already showed up, an
/// edit finds its row by it, and a row stays with its item as the rows around it change.
///
/// Keys compare by `==` / `hashCode`, so an `int`, a `String`, or a composite like `'${item.a}:${item.b}'`.
/// Anything with its own `==`, a record included, can key itself with `(item) => item`. A class without
/// one can't: an edited copy is a new object, so it would show as a 2nd row.
typedef ItemId<T extends Object> = Object Function(T item);

/// Extracts the group key for [item], for a list_smith list that shows its items in sections.
///
/// Keys are compared with `==` to decide where one group ends and the next begins, so use a type with
/// value equality (a `String`, `enum`, `int`, `DateTime`, and so on). Keep the extractor cheap: on the
/// async path it is called about twice per visible item to detect group boundaries during scroll.
typedef GroupKeyOf<T extends Object, K extends Object> = K Function(T item);

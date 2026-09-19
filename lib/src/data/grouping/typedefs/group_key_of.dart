/// Pulls the group key off [item], for a list showing its items in sections.
///
/// Keys compare with `==`, so use something with value equality (`String`, `enum`, `int`, `DateTime`).
/// Keep it cheap: the async path calls it about twice per visible item while scrolling.
typedef GroupKeyOf<T extends Object, K extends Object> = K Function(T item);

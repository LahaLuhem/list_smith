import 'package:flutter/widgets.dart';

/// Builds the section header shown above the first item of a group, given that group's [key].
///
/// Parallels the item builder, but receives the group [key] rather than an item, and no index (a
/// header is not an addressable list item). Called once per group, at the group's first item.
typedef GroupHeaderBuilder<K extends Object> = Widget Function(BuildContext context, K key);

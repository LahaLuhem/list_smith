import 'package:flutter/widgets.dart';

/// Builds the section header shown above the first item of a group, given that group's [key].
///
/// Like the item builder, but with the group [key] instead of an item and no index, since a header
/// isn't an addressable list item. Called once per group.
typedef GroupHeaderBuilder<K extends Object> = Widget Function(BuildContext context, K key);

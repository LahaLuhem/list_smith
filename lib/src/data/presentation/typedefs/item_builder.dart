import 'package:flutter/widgets.dart';

/// Builds the widget for a single list item, given the `item` and its `index` in the flattened
/// list.
typedef ItemBuilder<T extends Object> = Widget Function(BuildContext context, T item, int index);

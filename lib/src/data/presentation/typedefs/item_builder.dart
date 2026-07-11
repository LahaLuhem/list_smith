import 'package:flutter/widgets.dart';

/// Builds the widget for a single list item.
///
/// Receives the `item` and its `index` in the flattened list. The `(context, item, index)` shape
/// matches the common item-builder convention, so it reads the same as a hand-written `ListView.builder`.
typedef ItemBuilder<T extends Object> = Widget Function(BuildContext context, T item, int index);

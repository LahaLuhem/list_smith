import 'package:flutter/widgets.dart';

/// Builds one list item. The `index` is into the flattened list.
typedef ItemBuilder<T extends Object> = Widget Function(BuildContext context, T item, int index);

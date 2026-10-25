import 'package:flutter/widgets.dart';

/// Builds the header shown above a group, from that group's [key]. Once per group.
typedef GroupHeaderBuilder<K extends Object> = Widget Function(BuildContext context, K key);

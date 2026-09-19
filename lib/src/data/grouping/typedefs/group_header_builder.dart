import 'package:flutter/widgets.dart';

/// Builds the header above a group's 1st item, from that group's [key]. Once per group.
typedef GroupHeaderBuilder<K extends Object> = Widget Function(BuildContext context, K key);

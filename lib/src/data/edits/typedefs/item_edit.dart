import 'package:meta/meta.dart';

/// A local change to one item: its new value, or null once removed, and the edit counter when it was
/// made.
@internal
typedef ItemEdit<T extends Object> = ({T? item, int stamp});

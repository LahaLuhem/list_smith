import 'package:flutter/foundation.dart' show immutable;

@immutable
class const DemoItem({
  required final int id,
  required final String title,
  required final String subtitle,
}) {
  bool matches(String query) => title.toLowerCase().contains(query.toLowerCase());

  // Debug-only.
  // coverage:ignore-start
  @override
  String toString() => 'DemoItem(id: $id, title: $title)';
  // coverage:ignore-end
}

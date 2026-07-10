import 'package:flutter/foundation.dart' show immutable;

/// One row in the demo dataset. Deliberately tiny: a stable [id] plus two text
/// fields the item builders render, and (later) a searchable [title].
@immutable
class DemoItem {
  final int id;
  final String title;
  final String subtitle;

  const DemoItem({required this.id, required this.title, required this.subtitle});

  @override
  String toString() => 'DemoItem(id: $id, title: $title)';
}

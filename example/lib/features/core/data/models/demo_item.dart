import 'package:flutter/foundation.dart' show immutable;

@immutable
class DemoItem {
  final int id;
  final String title;
  final String subtitle;

  const new({required this.id, required this.title, required this.subtitle});

  bool matches(String query) => title.toLowerCase().contains(query.toLowerCase());

  @override
  String toString() => 'DemoItem(id: $id, title: $title)';
}

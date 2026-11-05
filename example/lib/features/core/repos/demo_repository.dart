import '../data/models/demo_item.dart';

class DemoRepository({
  final Duration latency = const Duration(milliseconds: 600),

  /// Not a round multiple of a typical page size, so the last page is partial.
  final int totalItems = 137,
}) {
  late final _items = List.generate(
    totalItems,
    (index) => DemoItem(
      id: index,
      title: 'Item ${index + 1}',
      subtitle: 'Row ${index + 1} of $totalItems',
    ),
    growable: false,
  );

  List<DemoItem> get items => _items;

  /// A page past the data comes back empty, which the default end policy reads as the end.
  Future<Iterable<DemoItem>> fetchPage(int pageIndex, int pageSize) async {
    await Future<void>.delayed(latency);

    return _items.skip(pageIndex * pageSize).take(pageSize);
  }

  Future<Iterable<DemoItem>> searchFetchPage(String query, int pageIndex, int pageSize) async {
    await Future<void>.delayed(latency);

    return _items.where((item) => item.matches(query)).skip(pageIndex * pageSize).take(pageSize);
  }

  /// The cursor is the next offset as a string, `null` once the data runs out. list_smith never looks
  /// inside it.
  Future<(Iterable<DemoItem>, Object?)> cursorFetchPage(Object? cursor, int pageSize) async {
    await Future<void>.delayed(latency);

    final start = cursor is String ? int.parse(cursor) : 0;
    final end = start + pageSize;

    return (_items.skip(start).take(pageSize), end >= _items.length ? null : '$end');
  }
}

import '../data/models/demo_item.dart';

class DemoRepository {
  final Duration latency;

  /// Not a round multiple of a typical page size, so the last page is partial.
  final int totalItems;

  new({this.latency = const Duration(milliseconds: 600), this.totalItems = 137});

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
  Future<List<DemoItem>> fetchPage(int pageIndex, int pageSize) async {
    await Future<void>.delayed(latency);

    final start = pageIndex * pageSize;
    if (start >= _items.length) return const [];

    final end = start + pageSize;

    return _items.sublist(start, end > _items.length ? _items.length : end);
  }

  Future<List<DemoItem>> searchFetchPage(String query, int pageIndex, int pageSize) async {
    await Future<void>.delayed(latency);

    final matchingItems = _items.where((item) => item.matches(query)).toList(growable: false);
    final start = pageIndex * pageSize;
    if (start >= matchingItems.length) return const [];

    final end = start + pageSize;

    return matchingItems.sublist(start, end > matchingItems.length ? matchingItems.length : end);
  }

  /// The cursor is the next offset as a string, `null` once the data runs out. list_smith never looks
  /// inside it.
  Future<(List<DemoItem>, Object?)> cursorFetchPage(Object? cursor, int pageSize) async {
    await Future<void>.delayed(latency);

    final start = cursor is String ? int.parse(cursor) : 0;
    if (start >= _items.length) return (const <DemoItem>[], null);

    final end = start + pageSize;
    final clampedEnd = end > _items.length ? _items.length : end;
    final nextCursor = clampedEnd >= _items.length ? null : '$clampedEnd';

    return (_items.sublist(start, clampedEnd), nextCursor);
  }
}

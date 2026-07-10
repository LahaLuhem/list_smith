import '../data/models/demo_item.dart';

/// A fake async data source backing every demo.
///
/// Holds a fixed, in-memory dataset and serves it a page at a time behind a
/// simulated network [latency], so the demos exercise the real loading, empty,
/// and end-of-list paths. [totalItems] is deliberately not a round multiple of a
/// typical page size, so the final page is partial. Search demos will grow a
/// query filter over this same dataset.
class DemoRepository {
  /// Simulated per-page network delay.
  final Duration latency;

  /// The size of the fixed dataset.
  final int totalItems;

  DemoRepository({this.latency = const Duration(milliseconds: 600), this.totalItems = 137});

  late final _items = List.generate(
    totalItems,
    (index) => DemoItem(
      id: index,
      title: 'Item ${index + 1}',
      subtitle: 'Row ${index + 1} of $totalItems',
    ),
    growable: false,
  );

  /// Returns the [pageIndex]th page (0-based) of at most [pageSize] items, after
  /// [latency]. An out-of-range page returns empty, which the default
  /// end-policy reads as the end of the data.
  Future<List<DemoItem>> fetchPage(int pageIndex, int pageSize) async {
    await Future<void>.delayed(latency);

    final start = pageIndex * pageSize;
    if (start >= _items.length) return const [];

    final end = start + pageSize;

    return _items.sublist(start, end > _items.length ? _items.length : end);
  }
}

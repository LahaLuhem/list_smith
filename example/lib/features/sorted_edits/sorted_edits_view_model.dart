import 'dart:async';

import 'package:collection/collection.dart';
import 'package:list_smith/list_smith.dart';
import 'package:pmvvm/pmvvm.dart';

import '/features/core/data/models/demo_item.dart';
import '/features/core/repos/sorted_demo_store.dart';

final class SortedEditsViewModel() extends ViewModel {
  static const _latency = Duration(milliseconds: 500);

  final _store = SortedDemoStore(_compareByTitle);

  final controller = ListSmithController<DemoItem>();

  final titleOrder = const SortedBy(_compareByTitle);

  Future<List<DemoItem>> fetchPage(PageRequest request) async {
    await Future<void>.delayed(_latency);

    return _store.items
        .skip(request.pageIndex * request.pageSize)
        .take(request.pageSize)
        .toList(growable: false);
  }

  void onRenamed(DemoItem item, String title) =>
      _save(DemoItem(id: item.id, title: title, subtitle: item.subtitle));

  void onAdded(String title) =>
      _save(DemoItem(id: _store.takeNewId(), title: title, subtitle: 'Added just now'));

  void _save(DemoItem draft) => unawaited(
    controller.upsertAsync(
      draft,
      commit: Future.delayed(_latency, () {
        _store.put(draft);

        return draft;
      }),
    ),
  );

  /// Item 9 before Item 10, then by id, since list_smith wants a strict order.
  static int _compareByTitle(DemoItem a, DemoItem b) {
    final byTitle = compareAsciiLowerCaseNatural(a.title, b.title);

    return byTitle != 0 ? byTitle : a.id.compareTo(b.id);
  }
}

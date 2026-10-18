import 'dart:async';

import 'package:collection/collection.dart';
import 'package:list_smith/list_smith.dart';
import 'package:pmvvm/pmvvm.dart';

import '/features/core/data/models/demo_item.dart';
import '/features/core/repos/demo_repository.dart';

/// [DemoRepository] is read-only, so this keeps a store of its own.
final class SortedEditsViewModel() extends ViewModel {
  static const _latency = Duration(milliseconds: 500);

  final _storedItems = DemoRepository().items.sorted(_compareByTitle);

  /// Below every existing id, so it's never taken.
  var _nextNewId = -1;

  final controller = ListSmithController<DemoItem>();

  final titleOrder = const SortedBy(_compareByTitle);

  Future<List<DemoItem>> fetchPage(PageRequest request) async {
    await Future<void>.delayed(_latency);

    return _storedItems
        .skip(request.pageIndex * request.pageSize)
        .take(request.pageSize)
        .toList(growable: false);
  }

  void onRenamed(DemoItem item, String title) =>
      _save(DemoItem(id: item.id, title: title, subtitle: item.subtitle));

  void onAdded(String title) =>
      _save(DemoItem(id: _nextNewId--, title: title, subtitle: 'Added just now'));

  void _save(DemoItem draft) => unawaited(
    controller.upsertAsync(
      draft,
      commit: Future.delayed(_latency, () {
        _storedItems
          ..removeWhere((item) => item.id == draft.id)
          ..insert(lowerBound(_storedItems, draft, compare: _compareByTitle), draft);

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

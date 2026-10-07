import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:list_smith/list_smith.dart';
import 'package:pmvvm/pmvvm.dart';

import '/features/core/data/models/demo_item.dart';
import '/features/core/repos/demo_repository.dart';

/// [DemoRepository] is read-only, so this keeps a store of its own.
final class EditsViewModel() extends ViewModel {
  static const _latency = Duration(milliseconds: 500);

  /// Sorted by id and read after the last id seen, so a delete can't make the next page skip a row
  /// the way an offset would.
  final _store = [...DemoRepository().items];

  /// Below every existing id, so the store sorts new items on top too.
  var _nextNewId = -1;

  final _shouldFailDeletesNotifier = ValueNotifier(false);

  final controller = ListSmithController<DemoItem>();

  ValueListenable<bool> get shouldFailDeletesListenable => _shouldFailDeletesNotifier;

  Future<(List<DemoItem>, Object?)> fetchPage(PageRequest request) async {
    await Future<void>.delayed(_latency);

    final afterId = request.previousSignal as int?;
    final remainingItems = _store
        .where((item) => afterId == null || item.id > afterId)
        .toList(growable: false);
    final pageItems = remainingItems.take(request.pageSize).toList(growable: false);

    return (pageItems, remainingItems.length > pageItems.length ? pageItems.last.id : null);
  }

  void onAddPressed() {
    final newId = _nextNewId--;
    final newItem = DemoItem(id: newId, title: 'New item ${-newId}', subtitle: 'Added just now');
    _store.insert(0, newItem);
    controller.upsert(newItem);
  }

  void onRenamed(DemoItem item, String title) {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) return;

    final renamedItem = DemoItem(id: item.id, title: trimmedTitle, subtitle: item.subtitle);
    _store[_store.indexWhere((storedItem) => storedItem.id == item.id)] = renamedItem;
    controller.upsert(renamedItem);
  }

  void onDeleted(DemoItem item) => unawaited(_removeAsync(item));

  // A handler named like the rest, called from the switch's onChanged.
  // ignore: use_setters_to_change_properties
  void onDeletesFailToggled({required bool value}) => _shouldFailDeletesNotifier.value = value;

  Future<void> _removeAsync(DemoItem item) async {
    try {
      await controller.removeAsync(item, commit: _deleteFromStore(item));
    } on Exception {
      // The row coming back says the delete failed.
    }
  }

  Future<void> _deleteFromStore(DemoItem item) async {
    final shouldFail = _shouldFailDeletesNotifier.value;
    await Future<void>.delayed(_latency);

    if (shouldFail) throw Exception('Simulated delete failure');
    _store.removeWhere((storedItem) => storedItem.id == item.id);
  }

  @override
  void dispose() {
    _shouldFailDeletesNotifier.dispose();

    super.dispose();
  }
}

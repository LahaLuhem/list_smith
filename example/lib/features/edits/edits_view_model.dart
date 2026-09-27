import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:list_smith/list_smith.dart';
import 'package:pmvvm/pmvvm.dart';

import '/features/core/data/models/demo_item.dart';
import '/features/core/repos/demo_repository.dart';

/// Backs the Edits demo. [DemoRepository] is read-only, so this keeps a store of its own.
final class EditsViewModel extends ViewModel {
  static const _latency = Duration(milliseconds: 500);

  /// Sorted by id and read after the last id seen, so a delete can't make the next page skip a row
  /// the way an offset would.
  final _store = [...DemoRepository().items];

  /// Below every existing id, so the store sorts new items on top too.
  var _nextNewId = -1;

  final _deletesFail = ValueNotifier(false);

  final controller = ListSmithController<DemoItem>();

  ValueListenable<bool> get deletesFail => _deletesFail;

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

  void onDeletePressed(DemoItem item) {
    if (_deleteFromStore(item)) controller.remove(item);
  }

  /// The row has to go before the store answers, so a failed delete only shows after a pull.
  void onDismissed(DemoItem item) {
    controller.remove(item);
    _deleteFromStore(item);
  }

  // A handler named like the rest, called from the switch's onChanged.
  // ignore: use_setters_to_change_properties
  void onDeletesFailToggled({required bool value}) => _deletesFail.value = value;

  /// Whether the store let the delete through.
  bool _deleteFromStore(DemoItem item) {
    if (_deletesFail.value) return false;
    _store.removeWhere((storedItem) => storedItem.id == item.id);

    return true;
  }

  @override
  void dispose() {
    _deletesFail.dispose();

    super.dispose();
  }
}

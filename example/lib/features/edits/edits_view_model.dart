import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier, VoidCallback;
import 'package:list_smith/list_smith.dart';
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart' show showPlatformToast;
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

  final _shouldFailSavesNotifier = ValueNotifier(false);

  final controller = ListSmithController<DemoItem>();

  ValueListenable<bool> get shouldFailSavesListenable => _shouldFailSavesNotifier;

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
    _upsertDraft(newItem, write: () => _store.insert(0, newItem));
  }

  void onRenamed(DemoItem item, String title) {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) return;

    final renamedItem = DemoItem(id: item.id, title: trimmedTitle, subtitle: item.subtitle);
    _upsertDraft(
      renamedItem,
      write: () {
        final index = _store.indexWhere((storedItem) => storedItem.id == item.id);
        if (index >= 0) _store[index] = renamedItem; // deleted while the rename was out
      },
    );
  }

  void onDeleted(DemoItem item) => unawaited(
    controller.removeAsync(
      item,
      commit: _writeLater(() => _store.removeWhere((storedItem) => storedItem.id == item.id)),
      onFailure: (_) => _showFailure("Couldn't delete ${item.title}"),
    ),
  );

  // A handler named like the rest, called from the switch's onChanged.
  // ignore: use_setters_to_change_properties
  void onSavesFailToggled({required bool value}) => _shouldFailSavesNotifier.value = value;

  void _upsertDraft(DemoItem draft, {required VoidCallback write}) => unawaited(
    controller.upsertAsync(
      draft,
      commit: _writeLater(write).then((_) => draft),
      onFailure: (_) => _showFailure("Couldn't save ${draft.title}"),
    ),
  );

  /// A save can fail after the screen has gone.
  void _showFailure(String message) {
    if (context.mounted) unawaited(showPlatformToast(context: context, message: message));
  }

  /// Runs [write] after a server's delay, or fails then if saves were failing when it was asked.
  Future<void> _writeLater(VoidCallback write) async {
    final shouldFail = _shouldFailSavesNotifier.value;
    await Future<void>.delayed(_latency);

    if (shouldFail) throw Exception('Simulated save failure');
    write();
  }

  @override
  void dispose() {
    _shouldFailSavesNotifier.dispose();

    super.dispose();
  }
}

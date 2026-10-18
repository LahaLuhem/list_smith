import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier, VoidCallback;
import 'package:list_smith/list_smith.dart';
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart' show showPlatformToast;
import 'package:pmvvm/pmvvm.dart';

import '/features/core/data/models/demo_item.dart';
import '/features/core/repos/sorted_demo_store.dart';

final class EditsViewModel() extends ViewModel {
  static const _latency = Duration(milliseconds: 500);

  /// By id, read after the last id seen, so no delete above can shift the next page. New ids go below
  /// every other, so new items sort on top.
  final _store = SortedDemoStore((a, b) => a.id.compareTo(b.id));

  final _shouldFailSavesNotifier = ValueNotifier(false);

  final controller = ListSmithController<DemoItem>();

  ValueListenable<bool> get shouldFailSavesListenable => _shouldFailSavesNotifier;

  Future<(List<DemoItem>, Object?)> fetchPage(PageRequest request) async {
    await Future<void>.delayed(_latency);

    final afterId = request.previousSignal as int?;
    final remainingItems = _store.items
        .where((item) => afterId == null || item.id > afterId)
        .toList(growable: false);
    final pageItems = remainingItems.take(request.pageSize).toList(growable: false);

    return (pageItems, remainingItems.length > pageItems.length ? pageItems.last.id : null);
  }

  void onAddPressed() {
    final newId = _store.takeNewId();
    _upsertDraft(DemoItem(id: newId, title: 'New item ${-newId}', subtitle: 'Added just now'));
  }

  void onRenamed(DemoItem item, String title) =>
      _upsertDraft(DemoItem(id: item.id, title: title, subtitle: item.subtitle));

  void onDeleted(DemoItem item) => unawaited(
    controller.removeAsync(
      item,
      commit: _writeLater(() => _store.remove(item.id)),
      onFailure: (_) => _showFailure("Couldn't delete ${item.title}"),
    ),
  );

  // A handler named like the rest, called from the switch's onChanged.
  // ignore: use_setters_to_change_properties
  void onSavesFailToggled({required bool value}) => _shouldFailSavesNotifier.value = value;

  void _upsertDraft(DemoItem draft) => unawaited(
    controller.upsertAsync(
      draft,
      commit: _writeLater(() => _store.put(draft)).then((_) => draft),
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

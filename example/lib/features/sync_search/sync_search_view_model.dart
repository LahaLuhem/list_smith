import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:pmvvm/pmvvm.dart';

import '/features/core/data/models/demo_item.dart';
import '/features/core/repos/demo_repository.dart';

/// Backs the Sync search demo: holds the full in-memory dataset and the live query, and hands both to
/// `ListSmith.sync`, which filters client-side.
final class SyncSearchViewModel extends ViewModel {
  final _repository = DemoRepository();
  final _queryNotifier = ValueNotifier('');

  /// The full dataset to search over.
  List<DemoItem> get items => _repository.items;

  /// The live search query, driven by the search field.
  ValueListenable<String> get queryListenable => _queryNotifier;

  // A setter can't be torn off as the search field's onChanged callback.
  // ignore: use_setters_to_change_properties
  void onQueryChanged(String value) => _queryNotifier.value = value;

  @override
  void dispose() {
    _queryNotifier.dispose();

    super.dispose();
  }
}

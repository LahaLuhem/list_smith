import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:pmvvm/pmvvm.dart';

import '/features/core/data/models/demo_item.dart';
import '/features/core/repos/demo_repository.dart';

/// Backs the Sync search demo: the full in-memory dataset plus the live query, both handed to `ListSmith.sync`.
final class SyncSearchViewModel extends ViewModel {
  final _repository = DemoRepository();
  final _queryNotifier = ValueNotifier('');

  /// The full dataset to search over.
  List<DemoItem> get items => _repository.items;

  /// The live search query, driven by the search field.
  ValueListenable<String> get queryListenable => _queryNotifier;

  // Torn off as an onChanged callback, so it can't be a setter.
  // ignore: use_setters_to_change_properties
  void onQueryChanged(String value) => _queryNotifier.value = value;

  @override
  void dispose() {
    _queryNotifier.dispose();

    super.dispose();
  }
}

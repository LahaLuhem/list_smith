import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:pmvvm/pmvvm.dart';

import '/features/core/data/models/demo_item.dart';
import '/features/core/repos/demo_repository.dart';

/// The categories the demo cycles through, one per row by id.
const _categories = ['Alpha', 'Beta', 'Gamma'];

/// Backs the Grouping demo: the in-memory dataset plus the live query, handed to `ListSmith.sync`
/// with a `Grouping` so the filtered items render in labelled sections.
final class GroupingViewModel extends ViewModel {
  final _repository = DemoRepository();
  final _queryNotifier = ValueNotifier('');

  /// The full dataset to group and search over.
  List<DemoItem> get items => _repository.items;

  /// The live search query, driven by the search field.
  ValueListenable<String> get queryListenable => _queryNotifier;

  /// The section [item] belongs to (cycled by id): the grouping key. A concrete `String Function(
  /// DemoItem)` so `Grouping.by` infers its types instead of collapsing them to `Object`.
  String categoryOf(DemoItem item) => _categories[item.id % _categories.length];

  // A setter can't be torn off as the search field's onChanged callback.
  // ignore: use_setters_to_change_properties
  void onQueryChanged(String value) => _queryNotifier.value = value;

  @override
  void dispose() {
    _queryNotifier.dispose();

    super.dispose();
  }
}

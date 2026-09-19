import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:pmvvm/pmvvm.dart';

import '/features/core/data/models/demo_item.dart';
import '/features/core/repos/demo_repository.dart';

/// The categories the demo cycles through, one per row by id.
const _categories = ['Alpha', 'Beta', 'Gamma'];

/// Backs the Grouping demo: the in-memory dataset plus the live query, handed to `ListSmith.sync` with
/// a `Grouping` so the filtered items render in labelled sections.
final class GroupingViewModel extends ViewModel {
  final _repository = DemoRepository();
  final _queryNotifier = ValueNotifier('');

  /// The full dataset to group and search over.
  List<DemoItem> get items => _repository.items;

  /// The live search query, driven by the search field.
  ValueListenable<String> get queryListenable => _queryNotifier;

  /// The section [item] belongs to, cycled by id. Typed concretely so `Grouping.by` infers `K` instead
  /// of widening it to `Object`.
  String categoryOf(DemoItem item) => _categories[item.id % _categories.length];

  // Torn off as an onChanged callback, so it can't be a setter.
  // ignore: use_setters_to_change_properties
  void onQueryChanged(String value) => _queryNotifier.value = value;

  @override
  void dispose() {
    _queryNotifier.dispose();

    super.dispose();
  }
}

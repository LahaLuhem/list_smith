import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:pmvvm/pmvvm.dart';

import '/features/core/data/models/demo_item.dart';
import '/features/core/repos/demo_repository.dart';

const _categories = ['Alpha', 'Beta', 'Gamma'];

final class GroupingViewModel extends ViewModel {
  final _repository = DemoRepository();
  final _queryNotifier = ValueNotifier('');

  List<DemoItem> get items => _repository.items;

  ValueListenable<String> get queryListenable => _queryNotifier;

  /// Typed concretely so `Grouping.by` infers `K` instead of widening it to `Object`.
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

import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:pmvvm/pmvvm.dart';

import '../core/data/models/demo_item.dart';
import '../core/repos/demo_repository.dart';

/// Backs the Custom surfaces demo. Wraps the repository fetch with an optional
/// injected failure, so the error and retry surfaces can be exercised on demand.
///
/// The failure flag is a scoped [ValueNotifier] rather than `notifyListeners()`
/// state: flipping it only needs to rebuild the toggle switch, not the whole
/// view (which holds the list). See `CODESTYLE.md`.
final class CustomSurfacesViewModel extends ViewModel {
  final _repository = DemoRepository();
  final _shouldInjectFailuresNotifier = ValueNotifier(false);

  ValueListenable<bool> get shouldInjectFailuresListenable => _shouldInjectFailuresNotifier;

  // Simple case
  // ignore: use_setters_to_change_properties
  void onFailureToggled({required bool value}) => _shouldInjectFailuresNotifier.value = value;

  Future<List<DemoItem>> fetchPage(int pageIndex, int pageSize) async {
    final page = await _repository.fetchPage(pageIndex, pageSize);
    if (_shouldInjectFailuresNotifier.value) throw Exception('Simulated network failure');

    return page;
  }

  @override
  void dispose() {
    _shouldInjectFailuresNotifier.dispose();

    super.dispose();
  }
}

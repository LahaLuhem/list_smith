import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:list_smith/list_smith.dart';
import 'package:pmvvm/pmvvm.dart';

import '/features/core/data/models/demo_item.dart';
import '/features/core/repos/demo_repository.dart';

/// Backs the Custom surfaces demo, wrapping the repository fetch with an optional injected failure
/// so the error and retry surfaces can be exercised.
///
/// The failure flag is a scoped [ValueNotifier]: flipping it rebuilds the toggle, not the view that
/// holds the list. See `CODESTYLE.md` *State management*.
final class CustomSurfacesViewModel extends ViewModel {
  final _repository = DemoRepository();
  final _shouldInjectFailuresNotifier = ValueNotifier(false);

  ValueListenable<bool> get shouldInjectFailuresListenable => _shouldInjectFailuresNotifier;

  // Simple case
  // ignore: use_setters_to_change_properties
  void onFailureToggled({required bool value}) => _shouldInjectFailuresNotifier.value = value;

  Future<List<DemoItem>> fetchPage(PageRequest request) async {
    final page = await _repository.fetchPage(request.pageIndex, request.pageSize);
    if (_shouldInjectFailuresNotifier.value) throw Exception('Simulated network failure');

    return page;
  }

  @override
  void dispose() {
    _shouldInjectFailuresNotifier.dispose();

    super.dispose();
  }
}

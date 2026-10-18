import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:pmvvm/pmvvm.dart';

import '../data/models/demo_item.dart';

mixin FailureInjectionMixin on ViewModel {
  final _shouldInjectFailuresNotifier = ValueNotifier(false);

  ValueListenable<bool> get shouldInjectFailuresListenable => _shouldInjectFailuresNotifier;

  bool get shouldInjectFailures => _shouldInjectFailuresNotifier.value;

  // Torn off as an onChanged callback, so it can't be a setter.
  // ignore: use_setters_to_change_properties
  void onInjectFailuresToggled({required bool value}) =>
      _shouldInjectFailuresNotifier.value = value;

  /// The page, unless failures are on by the time it lands.
  Future<List<DemoItem>> withInjectedFailures(Future<List<DemoItem>> pageFuture) async {
    final page = await pageFuture;
    if (shouldInjectFailures) throw Exception('Simulated network failure');

    return page;
  }

  @override
  void dispose() {
    _shouldInjectFailuresNotifier.dispose();

    super.dispose();
  }
}

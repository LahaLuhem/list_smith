import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:list_smith/list_smith.dart';
import 'package:pmvvm/pmvvm.dart';

import '/features/core/data/models/demo_item.dart';

/// Backs the Reload demo: a paginated feed whose items are stamped with a per-page fetch count, so a
/// pull-to-refresh visibly re-stamps whatever it reloads. The reload strategy, its concurrency, and its
/// error handling are live knobs, and a failure can be injected on the next reload to compare
/// best-effort with all-or-nothing.
///
/// The three config knobs all feed the list's `PullToRefresh`, so they use `notifyListeners()` (the
/// many-sites case); the failure toggle is read only inside [fetchPage], so it is a scoped
/// `ValueNotifier` that rebuilds just its own switch. See `CODESTYLE.md`.
final class ReloadViewModel extends ViewModel {
  static const _dataPages = 6;
  static const _failPage = 1;
  static const _latency = Duration(milliseconds: 500);

  /// Per-page fetch count, stamped onto each item so reloads are visible; not reactive state.
  final _attempts = <int, int>{};
  final _injectFailures = ValueNotifier(false);

  var _keepDepth = true;
  var _concurrency = 1;
  var _atomic = false;

  bool get keepDepth => _keepDepth;

  int get concurrency => _concurrency;

  bool get atomic => _atomic;

  /// Whether the next reload should fail one page (to exercise the error policy); read live by
  /// [fetchPage].
  ValueListenable<bool> get injectFailures => _injectFailures;

  /// The reload strategy the current knobs describe, handed to `PullToRefresh`.
  Reload get reload => _keepDepth
      ? ReloadToCurrentDepth(
          concurrency: _concurrency,
          onError: _atomic ? .allOrNothing : .commitSucceeded,
        )
      : const ResetToFirstPage();

  Future<List<DemoItem>> fetchPage(int pageIndex, int pageSize) async {
    await Future<void>.delayed(_latency);

    final attempt = _attempts[pageIndex] = (_attempts[pageIndex] ?? 0) + 1;
    if (_injectFailures.value && pageIndex == _failPage && attempt > 1) {
      throw Exception('Simulated reload failure on page $pageIndex');
    }
    if (pageIndex >= _dataPages) return const [];

    return List.generate(pageSize, (index) {
      final number = pageIndex * pageSize + index + 1;

      return DemoItem(
        id: number,
        title: 'Item $number',
        subtitle: 'Page $pageIndex · load #$attempt',
      );
    }, growable: false);
  }

  void onKeepDepthToggled({required bool value}) {
    _keepDepth = value;
    notifyListeners();
  }

  void onConcurrencyChanged(double value) {
    _concurrency = value.round();
    notifyListeners();
  }

  void onAtomicToggled({required bool value}) {
    _atomic = value;
    notifyListeners();
  }

  // A setter can't be torn off as the switch's onChanged callback.
  // ignore: use_setters_to_change_properties
  void onInjectFailuresToggled({required bool value}) => _injectFailures.value = value;

  @override
  void dispose() {
    _injectFailures.dispose();

    super.dispose();
  }
}

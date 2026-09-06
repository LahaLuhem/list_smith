import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:list_smith/list_smith.dart';
import 'package:pmvvm/pmvvm.dart';

import '/features/core/data/models/demo_item.dart';

/// Backs the Reload demo. Items are stamped with a per-page fetch count, so a pull visibly
/// re-stamps whatever it reloaded.
///
/// The three config knobs all feed the list's `PullToRefresh`, so they take `notifyListeners()`.
/// The failure toggle is read only inside [fetchPage], so it is a scoped `ValueNotifier` rebuilding
/// just its own switch. See `CODESTYLE.md` *State management*.
final class ReloadViewModel extends ViewModel {
  static const _dataPages = 6;
  static const _failPage = 1;
  static const _latency = Duration(milliseconds: 500);

  /// Per-page fetch count, stamped onto each item so reloads are visible. Not reactive state.
  final _attempts = <int, int>{};
  final _injectFailures = ValueNotifier(false);
  final _refreshing = ValueNotifier(false);

  /// Drives the list from the "Refresh from code" button, running whatever [reload] describes.
  final controller = ListSmithController();

  var _keepDepth = true;
  var _concurrency = 1;
  var _atomic = false;

  bool get keepDepth => _keepDepth;

  int get concurrency => _concurrency;

  bool get atomic => _atomic;

  /// Whether the next reload should fail one page, to exercise the error policy. Read live by
  /// [fetchPage].
  ValueListenable<bool> get injectFailures => _injectFailures;

  /// Whether the code-driven refresh is still running, so only the button rebuilds while it is.
  ValueListenable<bool> get refreshing => _refreshing;

  /// The reload strategy the current knobs describe, handed to `PullToRefresh`.
  Reload get reload => _keepDepth
      ? ReloadToCurrentDepth(
          concurrency: _concurrency,
          onError: _atomic ? .allOrNothing : .commitSucceeded,
        )
      : const ResetToFirstPage();

  Future<List<DemoItem>> fetchPage(PageRequest request) async {
    final PageRequest(:pageIndex, :pageSize) = request;

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

  /// Refreshes without a pull, holding the button busy until `refresh()` completes. That is when
  /// the refetch lands under [ReloadToCurrentDepth], but only when the list clears under
  /// [ResetToFirstPage], where its own first-page loader takes over.
  Future<void> onRefreshPressed() async {
    _refreshing.value = true;

    try {
      await controller.refresh();
    } finally {
      if (!disposed) _refreshing.value = false;
    }
  }

  @override
  void dispose() {
    _injectFailures.dispose();
    _refreshing.dispose();

    super.dispose();
  }
}

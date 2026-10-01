import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:list_smith/list_smith.dart';
import 'package:pmvvm/pmvvm.dart';

import '/features/core/data/models/demo_item.dart';

/// Items are stamped with a per-page fetch count, so a pull visibly re-stamps whatever it reloaded.
///
/// The config knobs all feed `PullToRefresh`, so they take `notifyListeners()`. The failure toggle is
/// read only inside [fetchPage], so it is a scoped `ValueNotifier`. See `CODESTYLE.md` *State management*.
final class ReloadViewModel() extends ViewModel {
  static const _dataPages = 6;
  static const _failPage = 1;
  static const _latency = Duration(milliseconds: 500);

  final _attempts = <int, int>{};
  final _shouldInjectFailuresNotifier = ValueNotifier(false);
  final _isRefreshingNotifier = ValueNotifier(false);

  /// Runs the same [reload] as a pull, from the "Refresh from code" button.
  final controller = ListSmithController<DemoItem>();

  var _keepDepth = true;
  var _concurrency = 1;
  var _atomic = false;

  bool get keepDepth => _keepDepth;

  int get concurrency => _concurrency;

  bool get atomic => _atomic;

  /// Fails one page of the next reload, to exercise the error policy.
  ValueListenable<bool> get shouldInjectFailuresListenable => _shouldInjectFailuresNotifier;

  /// Whether the code-driven refresh is still running, so only the button rebuilds while it is.
  ValueListenable<bool> get isRefreshingListenable => _isRefreshingNotifier;

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
    if (_shouldInjectFailuresNotifier.value && pageIndex == _failPage && attempt > 1) {
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

  // Torn off as an onChanged callback, so it can't be a setter.
  // ignore: use_setters_to_change_properties
  void onInjectFailuresToggled({required bool value}) =>
      _shouldInjectFailuresNotifier.value = value;

  /// `refresh()` completes when the refetch lands under [ReloadToCurrentDepth], but under
  /// [ResetToFirstPage] as soon as the list clears and its first-page loader takes over.
  Future<void> onRefreshPressed() async {
    _isRefreshingNotifier.value = true;

    try {
      await controller.refresh();
    } finally {
      if (!disposed) _isRefreshingNotifier.value = false;
    }
  }

  @override
  void dispose() {
    _shouldInjectFailuresNotifier.dispose();
    _isRefreshingNotifier.dispose();

    super.dispose();
  }
}

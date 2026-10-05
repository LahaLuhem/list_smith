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
  static const _failPage = 0;
  static const _latency = Duration(milliseconds: 500);

  final _attempts = <int, int>{};
  final _shouldInjectFailuresNotifier = ValueNotifier(false);
  final _isRefreshingNotifier = ValueNotifier(false);
  final _lastErrorNotifier = ValueNotifier<Exception?>(null);

  late final observer = _LastErrorObserver(_lastErrorNotifier);

  /// Runs the same [reload] as a pull, from the "Refresh from code" button.
  final controller = ListSmithController<DemoItem>();

  var _keepDepth = true;
  var _concurrency = 1;
  var _atomic = false;

  bool get keepDepth => _keepDepth;

  int get concurrency => _concurrency;

  bool get atomic => _atomic;

  /// Fails every load of the 1st page after its first, to exercise the error policy.
  ValueListenable<bool> get shouldInjectFailuresListenable => _shouldInjectFailuresNotifier;

  /// The latest reload's error, since a reload that keeps depth leaves the rows as they were.
  ValueListenable<Exception?> get lastErrorListenable => _lastErrorNotifier;

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
    _lastErrorNotifier.dispose();

    super.dispose();
  }
}

final class _LastErrorObserver(final ValueNotifier<Exception?> _lastErrorNotifier)
    extends ListSmithObserver {
  @override
  void onReload(FetchTrigger trigger) => _lastErrorNotifier.value = null;

  @override
  void onError(Exception error, StackTrace stackTrace) => _lastErrorNotifier.value = error;
}

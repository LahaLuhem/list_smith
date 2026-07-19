import 'package:pmvvm/pmvvm.dart';

import '/features/core/data/models/demo_item.dart';

/// Backs the Playground demo. Holds the live-editable list config and serves a
/// deliberately gappy source (the first page is empty, data follows) so the
/// end-policy and empty-page knobs have a visible effect.
///
/// The preview depends on all of these knobs at once, so this uses
/// `notifyListeners()` (the many-sites case) rather than per-field notifiers.
/// See `CODESTYLE.md`.
final class PlaygroundViewModel extends ViewModel {
  static const _dataPages = {1, 2, 4, 5};

  var _pageSize = 20;
  var _emptyRunBeforeEnd = 2;
  var _pagePastEmpty = true;
  var _latencyMs = 600.0;
  var _pullToRefresh = true;
  var _separators = true;

  int get pageSize => _pageSize;

  int get emptyRunBeforeEnd => _emptyRunBeforeEnd;

  bool get pagePastEmpty => _pagePastEmpty;

  double get latencyMs => _latencyMs;

  bool get pullToRefresh => _pullToRefresh;

  bool get separators => _separators;

  void onPageSizeChanged(double value) {
    _pageSize = value.round();
    notifyListeners();
  }

  void onEmptyRunChanged(double value) {
    _emptyRunBeforeEnd = value.round();
    notifyListeners();
  }

  void onPagePastEmptyToggled({required bool value}) {
    _pagePastEmpty = value;
    notifyListeners();
  }

  void onLatencyChanged(double value) {
    _latencyMs = value;
    notifyListeners();
  }

  void onPullToRefreshToggled({required bool value}) {
    _pullToRefresh = value;
    notifyListeners();
  }

  void onSeparatorsToggled({required bool value}) {
    _separators = value;
    notifyListeners();
  }

  Future<List<DemoItem>> fetchPage(int pageIndex, int pageSize) async {
    await Future<void>.delayed(Duration(milliseconds: _latencyMs.round()));
    if (!_dataPages.contains(pageIndex)) return const [];

    return List.generate(pageSize, (index) {
      final number = pageIndex * pageSize + index + 1;

      return DemoItem(id: number, title: 'Item $number', subtitle: 'Page $pageIndex');
    }, growable: false);
  }
}

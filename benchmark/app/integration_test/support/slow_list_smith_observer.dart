import 'dart:io';

import 'package:list_smith/list_smith.dart';

/// A [ListSmithObserver] that synchronously blocks for [delay] on every callback, simulating a slow
/// logger or analytics flush a consumer might wire into the observer seam.
///
/// Callbacks fire synchronously on list_smith's own fetch, refresh and query-commit paths, so a
/// slow observer stalls its work and blocks the UI isolate. A genuine `dart:io` [sleep], pausing
/// the event loop exactly as a slow synchronous callback would. Mirrors BICC's `SlowObserver`.
final class SlowListSmithObserver extends ListSmithObserver {
  new({this.delay = const Duration(milliseconds: 50)});

  final Duration delay;
  final callCounts = <String, int>{};

  @override
  void onPageLoaded(int pageIndex, int itemCount, {required bool isSearchMode}) {
    _tally('onPageLoaded');
    sleep(delay);
  }

  @override
  void onError(Object error, StackTrace stackTrace) {
    _tally('onError');
    sleep(delay);
  }

  @override
  void onRefresh() {
    _tally('onRefresh');
    sleep(delay);
  }

  @override
  void onQueryCommitted(String query) {
    _tally('onQueryCommitted');
    sleep(delay);
  }

  @override
  void onSearchModeChanged({required bool isSearchMode}) {
    _tally('onSearchModeChanged');
    sleep(delay);
  }

  void _tally(String method) => callCounts[method] = (callCounts[method] ?? 0) + 1;
}

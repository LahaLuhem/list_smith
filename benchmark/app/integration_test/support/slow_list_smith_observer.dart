import 'dart:io';

import 'package:list_smith/list_smith.dart';

/// Blocks for [delay] on every callback, like a slow logger or analytics flush. Callbacks fire
/// synchronously on list_smith's fetch, reload and query paths, so the [sleep] blocks the UI isolate.
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
  void onReload(FetchTrigger trigger) {
    _tally('onReload');
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

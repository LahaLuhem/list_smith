// `_SilentObserver` is a private fixture; its name intentionally differs from the filename.
// ignore_for_file: prefer-match-file-name

import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:list_smith/list_smith.dart';

void main() {
  final observerDefaults = BddFeature('Observer defaults');

  Bdd(observerDefaults)
      .scenario('the no-op base bodies accept every event without effect')
      .given('an observer that overrides no events')
      .when('each lifecycle event fires')
      .then('every call returns normally')
      .run((_) {
        const observer = _SilentObserver();

        check(() {
          observer
            ..onPageLoaded(0, 3, isSearchMode: false)
            ..onError(Exception('x'), StackTrace.current)
            ..onRefresh()
            ..onQueryCommitted('a')
            ..onSearchModeChanged(isSearchMode: true);
        }).returnsNormally();
      });

  Bdd(observerDefaults)
      .scenario('the logging sink logs every event across both value branches without error')
      .given('the ready-made LoggingListSmithObserver')
      .when('each event fires, covering the search and empty-query branches')
      .then('every call returns normally')
      .run((_) {
        const observer = LoggingListSmithObserver();

        check(() {
          observer
            ..onPageLoaded(0, 3, isSearchMode: false)
            ..onPageLoaded(1, 0, isSearchMode: true)
            ..onError(Exception('boom'), StackTrace.current)
            ..onRefresh()
            ..onQueryCommitted('')
            ..onQueryCommitted('term')
            ..onSearchModeChanged(isSearchMode: true)
            ..onSearchModeChanged(isSearchMode: false);
        }).returnsNormally();
      });
}

/// A bare observer that overrides nothing, so each call runs [ListSmithObserver]'s no-op default body.
final class _SilentObserver extends ListSmithObserver {
  const _SilentObserver();
}

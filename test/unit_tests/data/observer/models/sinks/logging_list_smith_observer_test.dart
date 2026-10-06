import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:list_smith/list_smith.dart';

void main() {
  final loggingFeature = BddFeature('LoggingListSmithObserver');

  Bdd(loggingFeature)
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
            ..onReload(.refresh)
            ..onReload(.queryChanged)
            ..onQueryCommitted('')
            ..onQueryCommitted('term')
            ..onSearchModeChanged(isSearchMode: true)
            ..onSearchModeChanged(isSearchMode: false);
        }).returnsNormally();
      });
}

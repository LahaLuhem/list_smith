import 'package:list_smith/list_smith.dart';

/// A [ListSmithObserver] that records each event as a compact tag, for asserting the lifecycle a
/// list fires. Lives under `test/support/` so library code stays free of test scaffolding.
final class RecordingListSmithObserver extends ListSmithObserver {
  /// Every event received, in order, each a compact tag asserted with `checks`.
  final List<String> events = [];

  /// The error passed to the most recent [onError], or null if none has fired.
  Object? lastError;

  @override
  void onPageLoaded(int pageIndex, int itemCount, {required bool isSearchMode}) =>
      events.add('pageLoaded(index: $pageIndex, count: $itemCount, search: $isSearchMode)');

  @override
  void onError(Object error, StackTrace stackTrace) {
    lastError = error;
    events.add('error');
  }

  @override
  void onRefresh() => events.add('refresh');

  @override
  void onQueryCommitted(String query) => events.add('queryCommitted($query)');

  @override
  void onSearchModeChanged({required bool isSearchMode}) =>
      events.add('searchModeChanged($isSearchMode)');
}

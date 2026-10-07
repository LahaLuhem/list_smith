import 'package:list_smith/list_smith.dart';

/// A [ListSmithObserver] recording each event as a compact tag, for asserting the lifecycle a list fires.
final class RecordingListSmithObserver() extends ListSmithObserver {
  final List<String> events = [];

  /// The error passed to the most recent [onError], or null if none has fired.
  Exception? lastException;

  @override
  void onPageLoaded(int pageIndex, int itemCount, {required bool isSearchMode}) =>
      events.add('pageLoaded(index: $pageIndex, count: $itemCount, search: $isSearchMode)');

  @override
  void onError(Exception exception, StackTrace stackTrace) {
    lastException = exception;
    events.add('error');
  }

  @override
  void onReload(FetchTrigger trigger) => events.add('reload(${trigger.name})');

  @override
  void onQueryCommitted(String query) => events.add('queryCommitted($query)');

  @override
  void onSearchModeChanged({required bool isSearchMode}) =>
      events.add('searchModeChanged($isSearchMode)');
}

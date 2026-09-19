import 'dart:developer' as developer;

import '/src/data/pagination/enums/fetch_trigger.dart';
import '../list_smith_observer.dart';

/// A [ListSmithObserver] that logs every event to [developer.log] under the `list_smith` name.
///
/// Pass `observer: const LoggingListSmithObserver()` and events show up in the console and DevTools'
/// logging view, filterable by that name. Want your own name, structured records or filtered telemetry?
/// Subclass [ListSmithObserver] instead.
final class LoggingListSmithObserver extends ListSmithObserver {
  /// The logger name on every record. Filter DevTools by it.
  static const _name = 'list_smith';

  /// `package:logging`'s `Level.SEVERE`, so piping through it gives the level you'd expect.
  static const _severeLevel = 900;

  /// Creates it.
  const new();

  @override
  void onPageLoaded(int pageIndex, int itemCount, {required bool isSearchMode}) => developer.log(
    'page loaded: index $pageIndex, $itemCount items${isSearchMode ? ' (search)' : ''}',
    name: _name,
  );

  @override
  void onError(Object error, StackTrace stackTrace) => developer.log(
    'load failed',
    name: _name,
    error: error,
    stackTrace: stackTrace,
    level: _severeLevel,
  );

  @override
  void onReload(FetchTrigger trigger) =>
      developer.log('reload started: ${trigger.name}', name: _name);

  @override
  void onQueryCommitted(String query) =>
      developer.log(query.isEmpty ? 'query cleared' : 'query committed: $query', name: _name);

  @override
  void onSearchModeChanged({required bool isSearchMode}) =>
      developer.log('search mode ${isSearchMode ? 'entered' : 'left'}', name: _name);
}

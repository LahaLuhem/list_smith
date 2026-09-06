import 'dart:developer' as developer;

import '../list_smith_observer.dart';

/// A [ListSmithObserver] that logs every event to [developer.log] under the `list_smith` name.
///
/// For quick diagnostics: pass `observer: const LoggingListSmithObserver()` and every event turns
/// up in the console and DevTools' logging view, filterable by the `list_smith` source. Uses
/// [developer.log] rather than `print`, so the package stays `avoid_print`-clean. Want a custom
/// name, structured records, or filtered telemetry? Subclass [ListSmithObserver] instead.
final class LoggingListSmithObserver extends ListSmithObserver {
  /// The logger name on every record. Filter DevTools by it.
  static const _name = 'list_smith';

  /// Matches `package:logging`'s `Level.SEVERE`, so a consumer piping through it sees the level
  /// they expect.
  static const _severeLevel = 900;

  /// Creates a [LoggingListSmithObserver].
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
  void onRefresh() => developer.log('refresh triggered', name: _name);

  @override
  void onQueryCommitted(String query) =>
      developer.log(query.isEmpty ? 'query cleared' : 'query committed: $query', name: _name);

  @override
  void onSearchModeChanged({required bool isSearchMode}) =>
      developer.log('search mode ${isSearchMode ? 'entered' : 'left'}', name: _name);
}

import 'dart:developer' as developer;

import '../list_smith_observer.dart';

/// A [ListSmithObserver] that logs every event to [developer.log] under the `list_smith` name.
///
/// A ready-made sink for quick diagnostics: pass
/// `ListSmith.async(observer: const LoggingListSmithObserver())` to watch a list's load, error,
/// refresh, and search lifecycle in the console and Flutter DevTools' logging view (filter it by the
/// `list_smith` source). It uses [developer.log] rather than `print`, so the package stays
/// `avoid_print`-clean and a plain-Dart context still surfaces records on stdout. For a custom log
/// name, structured records, or filtered telemetry, subclass [ListSmithObserver] directly instead.
final class LoggingListSmithObserver extends ListSmithObserver {
  /// The logger name applied to every record; filter DevTools by it to isolate list_smith's events.
  static const _name = 'list_smith';

  /// Severity forwarded to [developer.log] for [onError]; matches `package:logging`'s `Level.SEVERE`
  /// so consumers piping through it see the record at the expected level.
  static const _severeLevel = 900;

  /// Creates a [LoggingListSmithObserver].
  const LoggingListSmithObserver();

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

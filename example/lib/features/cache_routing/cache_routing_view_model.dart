import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:list_smith/list_smith.dart';
import 'package:listenable_collections/listenable_collections.dart';
import 'package:pmvvm/pmvvm.dart';

import '/features/core/data/models/demo_item.dart';
import '/features/core/repos/demo_repository.dart';

/// Backs the Cache routing demo: a repository-with-a-cache in front of `ListSmith.async`, routed on
/// `PageRequest.trigger`.
///
/// The cache lives here rather than in [DemoRepository], which every other demo shares and none of
/// them should start caching. Items are re-stamped with the fetch number that produced them, so a
/// served-from-cache page is visibly the same page and a bypassed one is visibly new.
final class CacheRoutingViewModel extends ViewModel {
  /// Cap on the log so it can't grow without bound; the newest lines are kept.
  static const _maxLoggedFetches = 50;

  final _repository = DemoRepository(latency: const Duration(milliseconds: 400));
  final _cache = <int, List<DemoItem>>{};
  final _shouldRouteOnTriggerNotifier = ValueNotifier(true);
  final _logNotifier = ListNotifier<String>();

  var _fetchCount = 0;

  /// Whether the fetch honours [PageRequest.trigger]. Off, any cached page is served, so a
  /// pull-to-refresh hands back stale rows.
  ValueListenable<bool> get shouldRouteOnTriggerListenable => _shouldRouteOnTriggerNotifier;

  /// One line per fetch, newest first: the page, its trigger, and whether it hit the cache.
  ValueListenable<List<String>> get logListenable => _logNotifier;

  Future<List<DemoItem>> fetchPage(PageRequest request) async {
    final PageRequest(:pageIndex, :pageSize, :trigger) = request;
    final bypass = _shouldRouteOnTriggerNotifier.value && _bypassesCache(trigger);
    final cached = _cache[pageIndex];

    if (!bypass && cached != null) {
      _record('page $pageIndex · ${trigger.name} · cache');

      return cached;
    }

    final page = await _repository.fetchPage(pageIndex, pageSize);
    final stamped = _stamped(page, fetch: ++_fetchCount);
    _cache[pageIndex] = stamped;
    _record('page $pageIndex · ${trigger.name} · network${bypass ? ' (bypassed)' : ''}');

    return stamped;
  }

  // A refresh is the user asking for fresh data and a retry follows a failure, so neither should be
  // answered from the cache. The rest are ordinary reads.
  bool _bypassesCache(FetchTrigger trigger) => switch (trigger) {
    .refresh || .retry => true,
    .initialLoad || .nextPage || .queryChanged => false,
  };

  List<DemoItem> _stamped(List<DemoItem> page, {required int fetch}) => page
      .map((item) => DemoItem(id: item.id, title: item.title, subtitle: 'from fetch #$fetch'))
      .toList(growable: false);

  void _record(String line) {
    _logNotifier.insert(0, line);
    if (_logNotifier.length > _maxLoggedFetches) _logNotifier.removeLast();
  }

  /// Empties the log.
  void clearLog() => _logNotifier.clear();

  /// Drops every cached page, so the next fetch of each goes to the network again.
  void clearCache() {
    _cache.clear();
    _record('cache cleared');
  }

  // A setter can't be torn off as the switch's onChanged callback.
  // ignore: use_setters_to_change_properties
  void onRouteOnTriggerToggled({required bool value}) =>
      _shouldRouteOnTriggerNotifier.value = value;

  @override
  void dispose() {
    _shouldRouteOnTriggerNotifier.dispose();
    _logNotifier.dispose();

    super.dispose();
  }
}

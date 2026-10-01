import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:list_smith/list_smith.dart';
import 'package:listenable_collections/listenable_collections.dart';
import 'package:pmvvm/pmvvm.dart';

import '/features/core/data/models/demo_item.dart';
import '/features/core/repos/demo_repository.dart';

/// The cache lives here, not in [DemoRepository], which every other demo shares. Items carry the
/// fetch number that produced them, so a cached page is visibly the same one.
final class CacheRoutingViewModel extends ViewModel {
  static const _maxLoggedFetches = 50;

  final _repository = DemoRepository(latency: const Duration(milliseconds: 400));
  final _cache = <int, List<DemoItem>>{};
  final _shouldRouteOnTriggerNotifier = ValueNotifier(true);
  final _logNotifier = ListNotifier<String>();

  var _fetchCount = 0;

  /// Off, a pull-to-refresh hands back stale rows.
  ValueListenable<bool> get shouldRouteOnTriggerListenable => _shouldRouteOnTriggerNotifier;

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

  // A refresh asks for fresh data and a retry follows a failure, so both skip the cache. The rest
  // read it, invalidated included, since that's the store changing, not the network.
  bool _bypassesCache(FetchTrigger trigger) => switch (trigger) {
    .refresh || .retry => true,
    .initialLoad || .nextPage || .queryChanged || .invalidated => false,
  };

  List<DemoItem> _stamped(List<DemoItem> page, {required int fetch}) => page
      .map((item) => DemoItem(id: item.id, title: item.title, subtitle: 'from fetch #$fetch'))
      .toList(growable: false);

  void _record(String line) {
    _logNotifier.insert(0, line);
    if (_logNotifier.length > _maxLoggedFetches) _logNotifier.removeLast();
  }

  void clearLog() => _logNotifier.clear();

  void clearCache() {
    _cache.clear();
    _record('cache cleared');
  }

  // Torn off as an onChanged callback, so it can't be a setter.
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

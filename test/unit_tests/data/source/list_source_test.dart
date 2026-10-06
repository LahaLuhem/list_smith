import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:list_smith/list_smith.dart';
import 'package:list_smith/src/data/source/list_source.dart';

void main() {
  final sourcesFeature = BddFeature('List source search support');

  Bdd(sourcesFeature)
      .scenario('an async source supports search only with a search fetcher')
      .given('async sources with and without a search fetcher')
      .when('each is inspected')
      .then('supportsSearch reflects the fetcher')
      .run((_) {
        final plainSource = AsyncSource<int>(
          fetchPage: PageFetcher((_) async => const <int>[]),
          itemIdGetter: (item) => item,
          editTransition: const NoEditTransition(),
          pageSize: 20,
          endPolicy: const StopOnEmptyPagesPolicy(),
          onEmptyPage: const ShowEmptySurface(),
          refresh: const PullToRefresh(),
          search: const NoSearch(),
        );
        final searchableSource = AsyncSource<int>(
          fetchPage: PageFetcher((_) async => const <int>[]),
          itemIdGetter: (item) => item,
          editTransition: const NoEditTransition(),
          pageSize: 20,
          endPolicy: const StopOnEmptyPagesPolicy(),
          onEmptyPage: const ShowEmptySurface(),
          refresh: const PullToRefresh(),
          search: AsyncSearch(fetchPage: SearchPageFetcher((_) async => const <int>[])),
        );

        check(plainSource.supportsSearch).isFalse();
        check(searchableSource.supportsSearch).isTrue();
      });
}

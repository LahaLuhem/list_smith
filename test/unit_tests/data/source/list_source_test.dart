import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:list_smith/list_smith.dart';
import 'package:list_smith/src/data/source/list_source.dart';

import '../../../support/support.dart';

void main() {
  final sourcesFeature = BddFeature('List source search support');

  AsyncSource<int> asyncSource({Search<int> search = const NoSearch()}) => AsyncSource(
    fetchPage: PageFetcher((_) async => const <int>[]),
    itemIdGetter: (item) => item,
    editTransition: const NoEditTransition(),
    pageSize: 20,
    endPolicy: const StopOnEmptyPagesPolicy(),
    onEmptyPage: const ShowEmptySurface(),
    refresh: const PullToRefresh(),
    search: search,
  );

  Bdd(sourcesFeature)
      .scenario('an async source supports search only with a search fetcher')
      .given('async sources with and without a search fetcher')
      .when('each is inspected')
      .then('supportsSearch reflects the fetcher')
      .run((_) {
        final searchableSource = asyncSource(
          search: AsyncSearch(fetchPage: SearchPageFetcher((_) async => const <int>[])),
        );

        check(asyncSource().supportsSearch).isFalse();
        check(searchableSource.supportsSearch).isTrue();
      });

  final logFormFeature = BddFeature('ListSource log form');

  const valueKey = 'value';
  Bdd(logFormFeature)
      .scenario('every list source reads as itself in a log')
      .given('the list source <$valueKey>')
      .when('it is turned into a string')
      .then("it reads as itself, not as Dart's default Instance of")
      .example(val(valueKey, asyncSource()))
      .example(val(valueKey, SyncSource<String>(items: const ['a'], searchBy: (_, _) => true)))
      .run((context) => check(context.example.val(valueKey) as Object).readsAsItself());
}

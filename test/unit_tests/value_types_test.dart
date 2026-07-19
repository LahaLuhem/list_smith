import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:list_smith/list_smith.dart';
import 'package:list_smith/src/data/source/list_source.dart';

void main() {
  final refreshState = BddFeature('ListSmithRefreshState value semantics');

  Bdd(refreshState)
      .scenario('equal phase and value compare equal and share a hashCode')
      .given('two refresh states with the same phase and value')
      .when('they are compared')
      .then('they are equal, their hashCodes match, and toString names the phase')
      .run((_) {
        const one = ListSmithRefreshState(phase: .armed, value: 1);
        const same = ListSmithRefreshState(phase: .armed, value: 1);

        check(one).equals(same);
        check(one.hashCode).equals(same.hashCode);
        check(one.toString())
          ..contains('ListSmithRefreshState')
          ..contains('armed');
      });

  Bdd(refreshState)
      .scenario('a difference in phase or in value compares unequal')
      .given('a base refresh state')
      .when('it is compared to states differing in phase or in value')
      .then('neither is equal to the base')
      .run((_) {
        const base = ListSmithRefreshState(phase: .idle, value: 0);
        const otherPhase = ListSmithRefreshState(phase: .dragging, value: 0);
        const otherValue = ListSmithRefreshState(phase: .idle, value: 0.5);

        check(base == otherPhase).isFalse();
        check(base == otherValue).isFalse();
      });

  final scrollConfig = BddFeature('ListScrollConfig string form');

  Bdd(scrollConfig)
      .scenario('toString names each configured knob')
      .given('a config with padding, reverse, direction, and cache extent set')
      .when('it is converted to a string')
      .then('the string names the configured values')
      .run((_) {
        const config = ListScrollConfig(
          padding: .all(8),
          reverse: true,
          scrollDirection: .horizontal,
          cacheExtent: 250,
        );

        check(config.toString())
          ..contains('reverse: true')
          ..contains('horizontal')
          ..contains('250');
      });

  final endPolicies = BddFeature('End policy string form');

  Bdd(endPolicies)
      .scenario('each end policy names its configuration in toString')
      .given('a StopOnEmptyPages policy and a FixedPageCount policy')
      .when('each is converted to a string')
      .then('the string names the policy and its value')
      .run((_) {
        check(const StopOnEmptyPagesPolicy(emptyRunBeforeEnd: 2).toString())
          ..contains('StopOnEmptyPagesPolicy')
          ..contains('2');
        check(const FixedPageCountPolicy(pageCount: 5).toString())
          ..contains('FixedPageCountPolicy')
          ..contains('5');
        check(const ExplicitHasMorePolicy().toString()).contains('ExplicitHasMorePolicy');
        check(const StopOnNullSignalPolicy().toString()).contains('StopOnNullSignalPolicy');
      });

  final refreshes = BddFeature('Refresh string form');

  Bdd(refreshes)
      .scenario('each refresh case names itself in toString')
      .given('a PullToRefresh and a NoRefresh')
      .when('each is converted to a string')
      .then('the string is the compact case form')
      .run((_) {
        check(const PullToRefresh().toString()).equals('PullToRefresh()');
        check(const NoRefresh().toString()).equals('NoRefresh()');
      });

  final searches = BddFeature('Search string form');

  Bdd(searches)
      .scenario('each search case names itself in toString')
      .given('a NoSearch and an AsyncSearch')
      .when('each is converted to a string')
      .then('the string is the compact case form, and AsyncSearch names its cache policy')
      .run((_) {
        check(const NoSearch().toString()).equals('NoSearch()');
        check(
          AsyncSearch<int>(
            fetchPage: SearchPageFetcher((_, _, _) async => const <int>[]),
          ).toString(),
        ).equals('AsyncSearch(cachePolicy: ReplaceCachePolicy())');
      });

  final emptyPageBehaviours = BddFeature('EmptyPageBehaviour string form');

  Bdd(emptyPageBehaviours)
      .scenario('each empty-page behaviour names itself in toString')
      .given('a ShowEmptySurface and AdvanceToFirstNonEmpty (capped and uncapped)')
      .when('each is converted to a string')
      .then('the string is the compact case form, and AdvanceToFirstNonEmpty names its cap')
      .run((_) {
        check(const ShowEmptySurface().toString()).equals('ShowEmptySurface()');
        check(const AdvanceToFirstNonEmpty().toString())
          ..contains('AdvanceToFirstNonEmpty')
          ..contains('null');
        check(const AdvanceToFirstNonEmpty(maxPages: 7).toString())
          ..contains('AdvanceToFirstNonEmpty')
          ..contains('7');
      });

  final sources = BddFeature('List source string form and search support');

  Bdd(sources)
      .scenario('an async source reports its config and whether it supports search')
      .given('async sources with and without a search fetcher')
      .when('each is inspected')
      .then('supportsSearch reflects the fetcher and toString names the config')
      .run((_) {
        final plain = AsyncSource<int>(
          fetchPage: PageFetcher((_, _) async => const <int>[]),
          pageSize: 20,
          endPolicy: const StopOnEmptyPagesPolicy(),
          onEmptyPage: const ShowEmptySurface(),
          refresh: const PullToRefresh(),
          search: const NoSearch(),
        );
        final searchable = AsyncSource<int>(
          fetchPage: PageFetcher((_, _) async => const <int>[]),
          pageSize: 20,
          endPolicy: const StopOnEmptyPagesPolicy(),
          onEmptyPage: const ShowEmptySurface(),
          refresh: const PullToRefresh(),
          search: AsyncSearch(fetchPage: SearchPageFetcher((_, _, _) async => const <int>[])),
        );

        check(plain.supportsSearch).isFalse();
        check(searchable.supportsSearch).isTrue();
        check(plain.toString())
          ..contains('AsyncSource')
          ..contains('pageSize: 20');
      });

  Bdd(sources)
      .scenario('a sync source has a compact string form')
      .given('a sync source over some items')
      .when('it is converted to a string')
      .then('the string is the compact SyncSource() form')
      .run((_) {
        final source = SyncSource<String>(items: const ['a', 'b'], searchBy: (_, _) => true);

        check(source.toString()).equals('SyncSource()');
      });
}

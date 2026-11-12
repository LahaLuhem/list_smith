// Test-local fixtures share the file with the scenarios that use them.
// ignore_for_file: prefer-match-file-name

import 'dart:async';

import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:fake_async/fake_async.dart';
import 'package:list_smith/src/utils/query_debouncer.dart';

void main() {
  final debouncerFeature = BddFeature('Query debouncing');

  const committedKey = 'committed';
  const queryKey = 'query';
  const commitsKey = 'commits';
  const dropKey = 'drop';

  Bdd(debouncerFeature)
      .scenario(
        'commits the trimmed query, one shorter than minSearchLength as no query, and nothing '
        'already showing',
      )
      .given('<$committedKey> committed, minSearchLength 3')
      .when('<$queryKey> is scheduled with no debounce')
      .then('it commits <$commitsKey>')
      .example(val(committedKey, 'apple'), val(queryKey, ' app '), val(commitsKey, 'app'))
      .example(val(committedKey, 'apple'), val(queryKey, 'ap'), val(commitsKey, ''))
      // Still no search either side, so nothing commits.
      .example(val(committedKey, ''), val(queryKey, 'ab'), val(commitsKey, null))
      // A call from code committed it under the gate, so a field showing it holds.
      .example(val(committedKey, '12'), val(queryKey, ' 12 '), val(commitsKey, null))
      .run((context) {
        final committedQueries = <String>[];
        fakeAsync((async) {
          QueryDebouncer(onCommitted: committedQueries.add).schedule(
            context.example.val(queryKey) as String,
            Duration.zero,
            minSearchLength: 3,
            committedQuery: context.example.val(committedKey) as String,
          );
          async.flushTimers();
        });

        check(committedQueries).deepEquals([?context.example.val(commitsKey) as String?]);
      });

  Bdd(debouncerFeature)
      .scenario('a query typed back to the committed one drops the commit on its way')
      .given('a debouncer with no search committed, minSearchLength 3')
      .when('abc is scheduled, then ab before the debounce ends')
      .then('nothing commits, since ab is still no search')
      .run((_) {
        const debounce = Duration(milliseconds: 300);
        final committedQueries = <String>[];
        fakeAsync((async) {
          final debouncer = QueryDebouncer(onCommitted: committedQueries.add)
            ..schedule('abc', debounce, minSearchLength: 3, committedQuery: '');
          async.elapse(debounce ~/ 2);
          debouncer.schedule('ab', debounce, minSearchLength: 3, committedQuery: '');
          async.flushTimers();
        });

        check(committedQueries).isEmpty();
      });

  Bdd(debouncerFeature)
      .scenario(
        'a call from code commits even the committed query, and one under minSearchLength as no '
        'search',
      )
      .given('<$committedKey> committed')
      .when('<$queryKey> is called with minSearchLength 3 and no debounce')
      .then('it commits <$commitsKey>')
      .example(val(committedKey, 'apple'), val(queryKey, ' apple '), val(commitsKey, 'apple'))
      .example(val(committedKey, 'apple'), val(queryKey, 'ap'), val(commitsKey, ''))
      // No search either side, as typed, so nothing commits.
      .example(val(committedKey, ''), val(queryKey, 'ap'), val(commitsKey, null))
      .run((context) {
        final committedQueries = <String>[];
        fakeAsync((async) {
          unawaited(
            QueryDebouncer(onCommitted: committedQueries.add).scheduleFromCode(
              context.example.val(queryKey) as String,
              Duration.zero,
              minSearchLength: 3,
              committedQuery: context.example.val(committedKey) as String,
              onCommitted: (query) async => committedQueries.add(query),
            ),
          );
          async.flushTimers();
        });

        check(committedQueries).deepEquals([?context.example.val(commitsKey) as String?]);
      });

  Bdd(debouncerFeature)
      .scenario(
        "a field showing the call on its way holds it, even under the list's minSearchLength",
      )
      .given('abc committed, and a call for 12 with minSearchLength 0 on its way')
      .when('the field shows 12 halfway through, with minSearchLength 3')
      .then('the call commits 12 when its own wait ends, and typing nothing')
      .run((_) {
        const debounce = Duration(milliseconds: 300);
        final typedQueries = <String>[];
        final calledQueries = <String>[];
        fakeAsync((async) {
          final debouncer = QueryDebouncer(onCommitted: typedQueries.add);
          unawaited(
            debouncer.scheduleFromCode(
              '12',
              debounce,
              minSearchLength: 0,
              committedQuery: 'abc',
              onCommitted: (query) async => calledQueries.add(query),
            ),
          );
          async.elapse(debounce ~/ 2);
          debouncer.schedule(' 12 ', debounce, minSearchLength: 3, committedQuery: 'abc');
          async.elapse(debounce ~/ 2);
        });

        check(calledQueries).deepEquals(['12']);
        check(typedQueries).isEmpty();
      });

  Bdd(debouncerFeature)
      .scenario('typing anything else replaces the call on its way')
      .given('a call for 12 on its way')
      .when('xyz is typed halfway through')
      .then('typing commits xyz, and the call nothing')
      .run((_) {
        const debounce = Duration(milliseconds: 300);
        final typedQueries = <String>[];
        final calledQueries = <String>[];
        fakeAsync((async) {
          final debouncer = QueryDebouncer(onCommitted: typedQueries.add);
          unawaited(
            debouncer.scheduleFromCode(
              '12',
              debounce,
              minSearchLength: 0,
              committedQuery: '',
              onCommitted: (query) async => calledQueries.add(query),
            ),
          );
          async.elapse(debounce ~/ 2);
          debouncer.schedule('xyz', debounce, minSearchLength: 0, committedQuery: '');
          async.flushTimers();
        });

        check(calledQueries).isEmpty();
        check(typedQueries).deepEquals(['xyz']);
      });

  Bdd(debouncerFeature)
      .scenario('a 2nd call replaces the 1st on its way')
      .given('a call for abc on its way')
      .when('a call for xyz comes halfway through')
      .then('only xyz commits')
      .run((_) {
        const debounce = Duration(milliseconds: 300);
        final committedQueries = <String>[];
        fakeAsync((async) {
          final debouncer = QueryDebouncer(onCommitted: committedQueries.add);
          Future<void> scheduleCall(String query) => debouncer.scheduleFromCode(
            query,
            debounce,
            minSearchLength: 0,
            committedQuery: '',
            onCommitted: (query) async => committedQueries.add(query),
          );
          unawaited(scheduleCall('abc'));
          async.elapse(debounce ~/ 2);
          unawaited(scheduleCall('xyz'));
          async.flushTimers();
        });

        check(committedQueries).deepEquals(['xyz']);
      });

  Bdd(debouncerFeature)
      .scenario("a call's caller waits for the work its commit starts")
      .given('a call for abc with no debounce')
      .when('it commits, and the work that starts ends later')
      .then('the caller is done only once that work is')
      .run((_) {
        final committedQueries = <String>[];
        var isCallDone = false;
        fakeAsync((async) {
          // In the fake zone, so completing it schedules where flushMicrotasks reaches.
          final workCompleter = Completer<void>();
          unawaited(
            QueryDebouncer(onCommitted: committedQueries.add)
                .scheduleFromCode(
                  'abc',
                  Duration.zero,
                  minSearchLength: 0,
                  committedQuery: '',
                  onCommitted: (query) {
                    committedQueries.add(query);

                    return workCompleter.future;
                  },
                )
                .then((_) => isCallDone = true),
          );
          async.flushTimers();
          check(committedQueries).deepEquals(['abc']);
          check(isCallDone).isFalse();

          workCompleter.complete();
          async.flushMicrotasks();
          check(isCallDone).isTrue();
        });
      });

  Bdd(debouncerFeature)
      .scenario('whatever drops a call on its way lets its caller go at once')
      .given('a call for abc on its way')
      .when('<$dropKey> drops it halfway through')
      .then('its caller is done right then')
      .example(val(dropKey, _Drop.typing))
      .example(val(dropKey, _Drop.anotherCall))
      .example(val(dropKey, _Drop.cancelling))
      .run((context) {
        const debounce = Duration(milliseconds: 300);
        var isCallDone = false;
        fakeAsync((async) {
          final debouncer = QueryDebouncer(onCommitted: <String>[].add);
          unawaited(
            debouncer
                .scheduleFromCode(
                  'abc',
                  debounce,
                  minSearchLength: 0,
                  committedQuery: '',
                  onCommitted: (_) => Future.syncValue(null),
                )
                .then((_) => isCallDone = true),
          );
          async.elapse(debounce ~/ 2);
          (context.example.val(dropKey) as _Drop).applyTo(debouncer);
          async.flushMicrotasks();
        });

        check(isCallDone).isTrue();
      });
}

/// What can drop a call on its way.
enum _Drop() {
  typing,
  anotherCall,
  cancelling;

  void applyTo(QueryDebouncer debouncer) {
    switch (this) {
      case typing:
        debouncer.schedule('xyz', Duration.zero, minSearchLength: 0, committedQuery: '');
      case anotherCall:
        unawaited(
          debouncer.scheduleFromCode(
            'xyz',
            Duration.zero,
            minSearchLength: 0,
            committedQuery: '',
            onCommitted: (_) => Future.syncValue(null),
          ),
        );
      case cancelling:
        debouncer.cancel();
    }
  }
}

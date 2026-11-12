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
      .scenario('typing anything else drops the call on its way, letting its caller go then')
      .given('abc committed, and a call for 12 on its way')
      .when('<$queryKey> is typed halfway through')
      .then('the call is done without committing, and typing commits <$commitsKey>')
      .example(val(queryKey, 'xyz'), val(commitsKey, 'xyz'))
      // Typed back to what's showing, so nothing commits, as with typing over typing.
      .example(val(queryKey, 'abc'), val(commitsKey, null))
      .run((context) {
        const debounce = Duration(milliseconds: 300);
        final typedQueries = <String>[];
        final calledQueries = <String>[];
        var isCallDone = false;
        fakeAsync((async) {
          final debouncer = QueryDebouncer(onCommitted: typedQueries.add);
          unawaited(
            debouncer
                .scheduleFromCode(
                  '12',
                  debounce,
                  minSearchLength: 0,
                  committedQuery: 'abc',
                  onCommitted: (query) async => calledQueries.add(query),
                )
                .then((_) => isCallDone = true),
          );
          async.elapse(debounce ~/ 2);
          debouncer.schedule(
            context.example.val(queryKey) as String,
            debounce,
            minSearchLength: 0,
            committedQuery: 'abc',
          );
          async.flushMicrotasks();
          check(isCallDone).isTrue();
          async.flushTimers();
        });

        check(calledQueries).isEmpty();
        check(typedQueries).deepEquals([?context.example.val(commitsKey) as String?]);
      });

  Bdd(debouncerFeature)
      .scenario('a 2nd call drops the 1st on its way, letting its caller go then')
      .given('a call for abc on its way')
      .when('a call for xyz comes halfway through')
      .then('the 1st is done without committing, and xyz commits')
      .run((_) {
        const debounce = Duration(milliseconds: 300);
        final committedQueries = <String>[];
        var isFirstCallDone = false;
        fakeAsync((async) {
          final debouncer = QueryDebouncer(onCommitted: committedQueries.add);
          Future<void> scheduleCall(String query) => debouncer.scheduleFromCode(
            query,
            debounce,
            minSearchLength: 0,
            committedQuery: '',
            onCommitted: (query) async => committedQueries.add(query),
          );
          unawaited(scheduleCall('abc').then((_) => isFirstCallDone = true));
          async.elapse(debounce ~/ 2);
          unawaited(scheduleCall('xyz'));
          async.flushMicrotasks();
          check(isFirstCallDone).isTrue();
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
      .scenario('disposing drops a call on its way, letting its caller go')
      .given('a call for abc on its way')
      .when('the debouncer is disposed halfway through')
      .then('the caller is done, and nothing commits')
      .run((_) {
        const debounce = Duration(milliseconds: 300);
        final committedQueries = <String>[];
        var isCallDone = false;
        fakeAsync((async) {
          final debouncer = QueryDebouncer(onCommitted: committedQueries.add);
          unawaited(
            debouncer
                .scheduleFromCode(
                  'abc',
                  debounce,
                  minSearchLength: 0,
                  committedQuery: '',
                  onCommitted: (query) async => committedQueries.add(query),
                )
                .then((_) => isCallDone = true),
          );
          async.elapse(debounce ~/ 2);
          debouncer.dispose();
          async.flushTimers();
        });

        check(isCallDone).isTrue();
        check(committedQueries).isEmpty();
      });
}

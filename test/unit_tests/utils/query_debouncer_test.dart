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
      .scenario('commits the trimmed query, and one shorter than minSearchLength as no query')
      .given('<$committedKey> committed, minSearchLength 3')
      .when('<$queryKey> is scheduled with no debounce')
      .then('it commits <$commitsKey>')
      .example(val(committedKey, 'apple'), val(queryKey, ' app '), val(commitsKey, 'app'))
      .example(val(committedKey, 'apple'), val(queryKey, 'ap'), val(commitsKey, ''))
      // Still no search either side, so nothing commits.
      .example(val(committedKey, ''), val(queryKey, 'ab'), val(commitsKey, null))
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
}

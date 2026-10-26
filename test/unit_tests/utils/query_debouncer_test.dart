import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:fake_async/fake_async.dart';
import 'package:list_smith/src/utils/query_debouncer.dart';

void main() {
  final debouncerFeature = BddFeature('Query debouncing');

  const seedKey = 'seed';
  const queryKey = 'query';
  const committedKey = 'committed';

  Bdd(debouncerFeature)
      .scenario('commits the trimmed query, and one shorter than minSearchLength as no query')
      .given('a debouncer seeded with <$seedKey>, minSearchLength 3')
      .when('<$queryKey> is scheduled with no debounce')
      .then('it commits <$committedKey>')
      .example(val(seedKey, 'apple'), val(queryKey, ' app '), val(committedKey, 'app'))
      .example(val(seedKey, 'apple'), val(queryKey, 'ap'), val(committedKey, ''))
      // Still no search either side, so nothing commits.
      .example(val(seedKey, 'a'), val(queryKey, 'ab'), val(committedKey, null))
      .run((context) {
        final committedQueries = <String>[];
        fakeAsync((async) {
          QueryDebouncer(onCommitted: committedQueries.add)
            ..seed(context.example.val(seedKey) as String, minSearchLength: 3)
            ..schedule(context.example.val(queryKey) as String, Duration.zero, minSearchLength: 3);
          async.flushTimers();
        });

        check(committedQueries).deepEquals([?context.example.val(committedKey) as String?]);
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
            ..seed('', minSearchLength: 3)
            ..schedule('abc', debounce, minSearchLength: 3);
          async.elapse(debounce ~/ 2);
          debouncer.schedule('ab', debounce, minSearchLength: 3);
          async.flushTimers();

          check(committedQueries).isEmpty();
          check(debouncer.committedQuery).equals('');
        });
      });
}

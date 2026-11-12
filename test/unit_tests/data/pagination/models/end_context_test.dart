import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:list_smith/list_smith.dart';

void main() {
  final endContextFeature = BddFeature('EndContext');

  const pageItemCountsKey = 'pageItemCounts';

  Bdd(endContextFeature)
      .scenario('the deprecated trailingEmptyRun answers like countTrailingEmptyPages')
      .given('a context over <$pageItemCountsKey>')
      .when('both are read')
      .then('they agree')
      .example(val(pageItemCountsKey, <int>[3]))
      .example(val(pageItemCountsKey, <int>[3, 0]))
      .example(val(pageItemCountsKey, <int>[0, 3, 0, 0]))
      .run((context) {
        final endContext = EndContext(
          pageItemCounts: context.example.val(pageItemCountsKey) as List<int>,
          pageSize: 20,
        );

        check(endContext.trailingEmptyRun).equals(endContext.countTrailingEmptyPages());
      });
}

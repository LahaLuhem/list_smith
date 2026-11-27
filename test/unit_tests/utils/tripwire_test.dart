import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:list_smith/src/utils/tripwire.dart';

void main() {
  final tripwireFeature = BddFeature('Tripwire');

  Bdd(tripwireFeature)
      .scenario('only the 1st trip() trips a tripwire, and it stays tripped')
      .given('a new tripwire')
      .when('it is tripped twice')
      .then('only the 1st trip() reports tripping it, and it reads tripped after both')
      .run((_) {
        final tripwire = Tripwire();
        check(tripwire.hasTripped).isFalse;

        check(tripwire.trip()).isTrue;
        check(tripwire.trip()).isFalse;
        check(tripwire.hasTripped).isTrue;
      });
}

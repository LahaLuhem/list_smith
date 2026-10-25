import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:list_smith/src/data/grouping/grouping.dart';

void main() {
  final headersFeature = BddFeature('Group headers');

  const keyKey = 'key';
  const lastIndexKey = 'lastIndex';
  const indexKey = 'index';

  Bdd(headersFeature)
      .scenario("finds a group's header again")
      .given("headers for groups 'a', 'b' and 'c'")
      .when('the header for <$keyKey> last sat at <$lastIndexKey>')
      .then('it sits at <$indexKey>')
      // Still where it was.
      .example(val(keyKey, 'b'), val(lastIndexKey, 1), val(indexKey, 1))
      // A header above it came or went.
      .example(val(keyKey, 'c'), val(lastIndexKey, 1), val(indexKey, 2))
      // The list got shorter than where it was.
      .example(val(keyKey, 'a'), val(lastIndexKey, 7), val(indexKey, 0))
      // Its group has gone.
      .example(val(keyKey, 'z'), val(lastIndexKey, 0), val(indexKey, null))
      .run((context) {
        final groupHeaders = GroupHeaders(
          headers: const [
            (itemIndex: 0, key: 'a'),
            (itemIndex: 5, key: 'b'),
            (itemIndex: 9, key: 'c'),
          ],
          isAfterItem: false,
          headerFor: (_, key) => Text('$key'),
        );

        check(
          groupHeaders.indexOf(
            context.example.val(keyKey) as String,
            context.example.val(lastIndexKey) as int,
          ),
        ).equals(context.example.val(indexKey) as int?);
      });
}

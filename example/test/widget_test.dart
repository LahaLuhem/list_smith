import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith_example/main.dart';

void main() {
  testWidgets('app builds and shows the placeholder message', (tester) async {
    await tester.pumpWidget(const ListSmithExampleApp());

    expect(find.text('list_smith list widgets are coming soon.'), findsOneWidget);
  });
}

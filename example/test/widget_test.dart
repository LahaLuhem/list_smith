import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith_example/main.dart';

void main() {
  testWidgets('app builds and shows a paginated item', (tester) async {
    await tester.pumpWidget(const ListSmithExampleApp());

    // Let the fake page fetch (a short delay) resolve; the neutral spinner
    // animates forever, so drive explicit pumps rather than pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.text('Item 1'), findsOneWidget);
  });
}

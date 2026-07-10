import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

void main() {
  testWidgets('async loads and renders the first page of items', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(),
          child: ListSmith<int>.async(
            fetchPage: (pageIndex, _) async => pageIndex == 0 ? const [1, 2, 3] : const <int>[],
            itemBuilder: (_, item, _) => Text('item $item'),
          ),
        ),
      ),
    );

    // The first-page fetch is scheduled post-frame and resolves asynchronously.
    await tester.pump();
    await tester.pump();

    expect(find.text('item 1'), findsOneWidget);
    expect(find.text('item 3'), findsOneWidget);
  });
}

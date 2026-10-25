import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:list_smith/src/data/presentation/presentation.dart';

void main() {
  final layoutFeature = BddFeature('Cell layout');

  const hasSeparatorsKey = 'hasSeparators';
  const headersKey = 'headers';
  const isHeaderAfterItemKey = 'isHeaderAfterItem';
  const cellsKey = 'cells';

  // Before items 0 and 2, or after items 1 and 2 as on a reversed list.
  const openingHeaders = [(itemIndex: 0, key: 'a'), (itemIndex: 2, key: 'b')];
  const closingHeaders = [(itemIndex: 1, key: 'a'), (itemIndex: 2, key: 'b')];

  CellLayout layoutOf(BddContext context) => CellLayout(
    itemCount: 3,
    hasSeparators: context.example.val(hasSeparatorsKey) as bool,
    headers: context.example.val(headersKey) as List<GroupHeader>,
    isHeaderAfterItem: context.example.val(isHeaderAfterItemKey) as bool,
  );

  String labelOf(Cell cell) => switch (cell.kind) {
    .header => 'h${cell.index}',
    .item => 'i${cell.index}',
    .separator => 's${cell.index}',
    .footer => 'f',
  };

  Bdd(layoutFeature)
      .scenario('lays out 3 items, their headers and separators, then the footer, in list order')
      .given('separators <$hasSeparatorsKey> and headers <$headersKey>')
      .when('each header sits after its item: <$isHeaderAfterItemKey>')
      .then('the children show <$cellsKey>')
      .example(
        val(hasSeparatorsKey, false),
        val(headersKey, const <GroupHeader>[]),
        val(isHeaderAfterItemKey, false),
        val(cellsKey, const ['i0', 'i1', 'i2', 'f']),
      )
      .example(
        val(hasSeparatorsKey, true),
        val(headersKey, const <GroupHeader>[]),
        val(isHeaderAfterItemKey, false),
        val(cellsKey, const ['i0', 's0', 'i1', 's1', 'i2', 's2', 'f']),
      )
      .example(
        val(hasSeparatorsKey, true),
        val(headersKey, openingHeaders),
        val(isHeaderAfterItemKey, false),
        val(cellsKey, const ['h0', 'i0', 's0', 'i1', 's1', 'h1', 'i2', 's2', 'f']),
      )
      .example(
        val(hasSeparatorsKey, true),
        val(headersKey, closingHeaders),
        val(isHeaderAfterItemKey, true),
        val(cellsKey, const ['i0', 's0', 'i1', 'h0', 's1', 'i2', 'h1', 's2', 'f']),
      )
      .example(
        val(hasSeparatorsKey, false),
        val(headersKey, closingHeaders),
        val(isHeaderAfterItemKey, true),
        val(cellsKey, const ['i0', 'i1', 'h0', 'i2', 'h1', 'f']),
      )
      .run((context) {
        final cellLayout = layoutOf(context);

        check(
          List.generate(
            cellLayout.childCount,
            (childIndex) => labelOf(cellLayout.cellAt(childIndex)),
          ),
        ).deepEquals(context.example.val(cellsKey) as List<String>);
      });

  Bdd(layoutFeature)
      .scenario('finds each row and header at the child that shows it')
      .given('separators <$hasSeparatorsKey> and headers <$headersKey>')
      .when('each header sits after its item: <$isHeaderAfterItemKey>')
      .then('each lookup lands on the child showing that row or header')
      .example(
        val(hasSeparatorsKey, true),
        val(headersKey, openingHeaders),
        val(isHeaderAfterItemKey, false),
      )
      .example(
        val(hasSeparatorsKey, true),
        val(headersKey, closingHeaders),
        val(isHeaderAfterItemKey, true),
      )
      .example(
        val(hasSeparatorsKey, false),
        val(headersKey, closingHeaders),
        val(isHeaderAfterItemKey, true),
      )
      .run((context) {
        final cellLayout = layoutOf(context);

        for (var itemIndex = 0; itemIndex < 3; itemIndex++) {
          check(cellLayout.cellAt(cellLayout.childIndexOfItem(itemIndex)))
              .equals((kind: CellKind.item, index: itemIndex));
        }
        for (var headerIndex = 0; headerIndex < 2; headerIndex++) {
          check(cellLayout.cellAt(cellLayout.childIndexOfHeader(headerIndex)))
              .equals((kind: CellKind.header, index: headerIndex));
        }
      });
}

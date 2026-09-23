import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_foundation/form_foundation.dart';

void main() {
  Widget harness(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

  group('AddButton', () {
    testWidgets('a single option adds directly, without a menu', (tester) async {
      String? added;
      await tester.pumpWidget(
        harness(
          AddButton<String>(
            typesToAdd: [NewItemOption(title: 'String', data: 'string')],
            onAdd: (data) => added = data,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(added, 'string');
      expect(find.byType(MenuItemButton), findsNothing);
    });

    testWidgets('multiple options open a menu; picking one adds its data', (tester) async {
      String? added;
      await tester.pumpWidget(
        harness(
          AddButton<String>(
            typesToAdd: [
              NewItemOption(title: 'String', data: 'string'),
              NewItemOption(title: 'Number', data: 'number'),
            ],
            onAdd: (data) => added = data,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('String'), findsOneWidget);
      expect(find.text('Number'), findsOneWidget);
      // Nothing added by merely opening the menu.
      expect(added, isNull);

      await tester.tap(find.text('Number'));
      await tester.pumpAndSettle();

      expect(added, 'number');
    });

    testWidgets('tapping the button again closes the open menu', (tester) async {
      await tester.pumpWidget(
        harness(
          AddButton<String>(
            typesToAdd: [
              NewItemOption(title: 'String', data: 'string'),
              NewItemOption(title: 'Number', data: 'number'),
            ],
            onAdd: (_) {},
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(find.text('String'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(find.text('String'), findsNothing);
    });

    testWidgets('disabled without onAdd, in both variants', (tester) async {
      for (final options in [
        [NewItemOption(title: 'Only', data: 'only')],
        [NewItemOption(title: 'A', data: 'a'), NewItemOption(title: 'B', data: 'b')],
      ]) {
        await tester.pumpWidget(harness(AddButton<String>(typesToAdd: options, onAdd: null)));

        expect(
          tester.widget<IconButton>(find.byType(IconButton)).onPressed,
          isNull,
          reason: 'with ${options.length} option(s)',
        );
      }
    });
  });
}

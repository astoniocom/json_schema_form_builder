import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_foundation/form_foundation.dart';

void main() {
  Widget harness(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('RemovableRow', () {
    testWidgets('renders the field and the delete button; tapping it calls onRemove', (tester) async {
      var removed = 0;
      await tester.pumpWidget(
        harness(RemovableRow(field: const Text('content'), onRemove: () => removed++)),
      );

      expect(find.text('content'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete));
      expect(removed, 1);
    });

    testWidgets('without onRemove there is no delete button', (tester) async {
      await tester.pumpWidget(
        harness(const RemovableRow(field: Text('content'), onRemove: null)),
      );

      expect(find.text('content'), findsOneWidget);
      expect(find.byIcon(Icons.delete), findsNothing);
    });

    testWidgets('a given dragHandle is rendered next to the actions', (tester) async {
      await tester.pumpWidget(
        harness(
          const RemovableRow(
            field: Text('content'),
            onRemove: null,
            dragHandle: Icon(Icons.drag_handle),
          ),
        ),
      );

      expect(find.byIcon(Icons.drag_handle), findsOneWidget);
    });

    testWidgets('the delete column is at least as tall as a standard field row', (tester) async {
      // The invisible MinHeightSetter next to the button keeps the actions
      // column from collapsing below a one-line TextField, so the delete
      // icon stays vertically centered against its field.
      await tester.pumpWidget(harness(RemovableRow(field: const TextField(), onRemove: () {})));

      final fieldHeight = tester.getSize(find.byType(TextField).first).height;
      final actionsRow = find.ancestor(of: find.byIcon(Icons.delete), matching: find.byType(Row)).first;
      expect(tester.getSize(actionsRow).height, greaterThanOrEqualTo(fieldHeight));
    });
  });
}

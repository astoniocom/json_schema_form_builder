import 'package:flutter_test/flutter_test.dart';
import 'package:form_foundation/form_foundation.dart';
import 'package:material_ui/material_ui.dart';

class DummyFieldState {
  DummyFieldState(
    this.uid,
    this.text,
  );

  final String uid; // ignore: unreachable_from_main
  final String text;
}

class MockFieldHandler implements FieldHandler<DummyFieldState, DummyFieldState, String> {
  @override
  Widget buildField({
    required BuildContext context,
    required DummyFieldState fieldState,
    required String displayContext,
    ValueChanged<DummyFieldState>? onChanged,
  }) {
    return Text('${fieldState.text} ($displayContext)');
  }
}

class MockRegistry extends FieldHandlerRegistry<DummyFieldState, String, MockFieldHandler> {
  final handler = MockFieldHandler();

  @override
  MockFieldHandler handlerForField(DummyFieldState field) => handler;
}

void main() {
  late MockRegistry mockRegistry;

  setUp(() {
    mockRegistry = MockRegistry();
  });

  Widget buildSubject({
    List<DummyFieldState>? children,
    Widget? addButton,
    Iterable<String>? errors,
    void Function(int index, DummyFieldState newValue)? onChanged,
    void Function(int index)? onRemoved,
    void Function(int oldIndex, int newIndex)? onReorder,
    String? title,
    EditorGroupView view = EditorGroupView.framed,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ListEditor<DummyFieldState, String, MockFieldHandler>(
          title: title ?? 'Test list',
          handlerRegistry: mockRegistry,
          displayContextForField: (index, field) => 'Index: $index',
          children: children,
          addButton: addButton,
          errors: errors,
          onChanged: onChanged,
          onRemoved: onRemoved,
          onReorder: onReorder,
          view: view,
        ),
      ),
    );
  }

  group('ListEditor Widget Tests', () {
    testWidgets('1. Displays the field list and title', (tester) async {
      final items = [
        DummyFieldState('1', 'Field 1'),
        DummyFieldState('2', 'Field 2'),
      ];

      await tester.pumpWidget(buildSubject(children: items));

      expect(find.text('Field 1 (Index: 0)'), findsOneWidget);
      expect(find.text('Field 2 (Index: 1)'), findsOneWidget);
      // In the default framed view the title is shown as the label of
      // EditorGroup's InputDecorator frame.
      expect(find.text('Test list'), findsOneWidget);
    });

    testWidgets('2. Adding via AddButton with IconButton (when there is only one type)', (tester) async {
      String? addedData;
      final types = [NewItemOption(title: 'Add line', data: 'new_item')];

      await tester.pumpWidget(
        buildSubject(
          addButton: AddButton<String>(
            typesToAdd: types,
            onAdd: (data) => addedData = data,
          ),
        ),
      );

      // An empty list collapses into a single-line framed EditorGroup with
      // the title as the frame label and the add button as its suffix icon.
      expect(find.text('Test list'), findsOneWidget);
      final addButton = find.byType(IconButton);
      expect(addButton, findsOneWidget);

      await tester.tap(addButton);
      await tester.pump();

      expect(addedData, equals('new_item'));
    });

    testWidgets('3. Adding via AddButton with a menu (when there is more than one option)', (tester) async {
      String? addedData;
      final types = [
        NewItemOption(title: 'Type A', data: 'type_a'),
        NewItemOption(title: 'Type B', data: 'type_b'),
      ];

      await tester.pumpWidget(
        buildSubject(
          addButton: AddButton<String>(
            typesToAdd: types,
            onAdd: (data) => addedData = data,
          ),
        ),
      );

      // Open the menu behind the add IconButton.
      final menuFinder = find.descendant(of: find.byType(MenuAnchor), matching: find.byIcon(Icons.add));
      expect(menuFinder, findsOneWidget);

      await tester.tap(menuFinder);
      await tester.pumpAndSettle(); // Wait for the menu animation

      // Select the second item
      await tester.tap(find.text('Type B'));
      await tester.pumpAndSettle();

      expect(addedData, equals('type_b'));
    });

    testWidgets('4. Removing an element from the list', (tester) async {
      int? removedIndex;
      final items = [
        DummyFieldState('1', 'Removable element'),
      ];

      await tester.pumpWidget(
        buildSubject(
          children: items,
          onRemoved: (index) => removedIndex = index,
        ),
      );

      // Look for the remove button inside RemovableRow (usually an IconButton/Icon)
      final removeIcon = find.byIcon(Icons.delete);
      // If a different remove icon is used (e.g. Icons.delete), replace it here
      expect(removeIcon, findsWidgets);

      await tester.tap(removeIcon.first);
      await tester.pump();

      expect(removedIndex, equals(0));
    });

    testWidgets('5. Reordering elements via Drag & Drop', (tester) async {
      int? reorderedOldIndex;
      int? reorderedNewIndex;

      final items = [
        DummyFieldState('1', 'Element A'),
        DummyFieldState('2', 'Element B'),
      ];

      await tester.pumpWidget(
        buildSubject(
          children: items,
          onReorder: (oldIdx, newIdx) {
            reorderedOldIndex = oldIdx;
            reorderedNewIndex = newIdx;
          },
        ),
      );

      // Look for the drag icons (Icons.drag_handle)
      final dragHandles = find.byIcon(Icons.drag_handle);
      expect(dragHandles, findsNWidgets(2));

      // Simulate dragging the first element onto the second one's position
      final firstHandle = dragHandles.at(0);
      final secondHandle = dragHandles.at(1);

      final gesture = await tester.startGesture(tester.getCenter(firstHandle));
      await tester.pump();

      // Move downward
      await gesture.moveTo(tester.getCenter(secondHandle));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(reorderedOldIndex, equals(0));
      expect(reorderedNewIndex, equals(1));
    });

    testWidgets('6. The feedback row keeps its position relative to the pointer as it was at grab time', (
      tester,
    ) async {
      final items = [
        DummyFieldState('1', 'Element A'),
        DummyFieldState('2', 'Element B'),
      ];

      await tester.pumpWidget(buildSubject(children: items, onReorder: (_, _) {}));

      final dragHandles = find.byIcon(Icons.drag_handle);
      // The grab point is not the handle's center, to verify that an
      // arbitrary offset is preserved rather than the centers coinciding.
      final grabPoint = tester.getCenter(dragHandles.at(0)) + const Offset(0, 3);

      // The rectangle of the whole row (the nearest Opacity above the handle).
      final rowFinder = find.ancestor(of: dragHandles.at(0), matching: find.byType(Opacity)).first;
      final rowRect = tester.getRect(rowFinder);
      final grabOffsetInRow = grabPoint - rowRect.topLeft;

      final gesture = await tester.startGesture(grabPoint);
      await tester.pump();
      // A small movement so that the drag starts.
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();

      // The feedback row is a Material with elevation 4 in the Overlay.
      final feedback = find.byWidgetPredicate((w) => w is Material && w.elevation == 4);
      expect(feedback, findsOneWidget);

      final pointerNow = grabPoint + const Offset(0, 30);
      final feedbackTopLeft = tester.getRect(feedback).topLeft;
      expect(
        (pointerNow - feedbackTopLeft).dy,
        moreOrLessEquals(grabOffsetInRow.dy, epsilon: 0.51),
        reason: 'the vertical pointer offset within the feedback row must match the offset at grab time',
      );
      expect(
        (pointerNow - feedbackTopLeft).dx,
        moreOrLessEquals(grabOffsetInRow.dx, epsilon: 0.51),
        reason: 'the horizontal pointer offset within the feedback row must match the offset at grab time',
      );

      await gesture.up();
      await tester.pump();
    });

    testWidgets('7. A row from one list is not accepted by another list', (tester) async {
      final firstListCalls = <(int, int)>[];
      final secondListCalls = <(int, int)>[];

      Widget buildList(String title, List<DummyFieldState> items, List<(int, int)> calls) {
        return ListEditor<DummyFieldState, String, MockFieldHandler>(
          title: title,
          handlerRegistry: mockRegistry,
          displayContextForField: (index, field) => 'Index: $index',
          children: items,
          onReorder: (oldIdx, newIdx) => calls.add((oldIdx, newIdx)),
        );
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                buildList('List 1', [DummyFieldState('1', 'A1'), DummyFieldState('2', 'A2')], firstListCalls),
                buildList('List 2', [DummyFieldState('3', 'B1'), DummyFieldState('4', 'B2')], secondListCalls),
              ],
            ),
          ),
        ),
      );

      final dragHandles = find.byIcon(Icons.drag_handle);
      expect(dragHandles, findsNWidgets(4));

      // Drag the first row of the first list onto a row of the second list.
      final gesture = await tester.startGesture(tester.getCenter(dragHandles.at(0)));
      await tester.pump();
      await gesture.moveTo(tester.getCenter(dragHandles.at(2)));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(firstListCalls, isEmpty, reason: 'a drop outside its own list must not reorder');
      expect(secondListCalls, isEmpty, reason: 'a foreign list must not accept the row');

      // Control check: reordering within the first list still works.
      final gesture2 = await tester.startGesture(tester.getCenter(dragHandles.at(0)));
      await tester.pump();
      await gesture2.moveTo(tester.getCenter(dragHandles.at(1)));
      await tester.pump();
      await gesture2.up();
      await tester.pump();

      expect(firstListCalls, equals([(0, 1)]));
      expect(secondListCalls, isEmpty);
    });

    testWidgets('8. The very first drag uses the row width, not the whole screen width', (tester) async {
      final items = [
        DummyFieldState('1', 'Element A'),
        DummyFieldState('2', 'Element B'),
      ];

      // The list is narrower than the screen (800), to distinguish the row width from the screen width.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 400,
                child: ListEditor<DummyFieldState, String, MockFieldHandler>(
                  title: 'Narrow list',
                  handlerRegistry: mockRegistry,
                  displayContextForField: (index, field) => 'Index: $index',
                  children: items,
                  onReorder: (_, _) {},
                ),
              ),
            ),
          ),
        ),
      );

      // The very first drag, without intermediate rebuilds.
      final dragHandles = find.byIcon(Icons.drag_handle);
      final gesture = await tester.startGesture(tester.getCenter(dragHandles.at(0)));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();

      final feedback = find.byWidgetPredicate((w) => w is Material && w.elevation == 4);
      expect(feedback, findsOneWidget);
      expect(
        tester.getSize(feedback).width,
        lessThan(500),
        reason: 'the feedback row must not stretch across the whole screen on the first drag',
      );

      await gesture.up();
      await tester.pump();
    });

    testWidgets('9. Displays the error list', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          errors: ['First error', 'Second error'],
        ),
      );

      // An empty editor collapses into an InputDecorator frame; the errors
      // are merged into its errorText.
      expect(find.text('First error\nSecond error'), findsOneWidget);
    });

    testWidgets('10. An empty expanded list displays the add button', (tester) async {
      String? addedData;
      final types = [NewItemOption(title: 'Add line', data: 'new_item')];

      await tester.pumpWidget(
        buildSubject(
          view: EditorGroupView.expanded,
          addButton: AddButton<String>(
            typesToAdd: types,
            onAdd: (data) => addedData = data,
          ),
        ),
      );

      // The expanded view has no collapsed frame with a suffix icon, so the
      // button row is the only way to fill an empty list.
      final addButton = find.byType(IconButton);
      expect(addButton, findsOneWidget);

      await tester.tap(addButton);
      await tester.pump();
      expect(addedData, equals('new_item'));
    });
  });
}

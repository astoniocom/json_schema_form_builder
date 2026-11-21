import 'package:flutter_test/flutter_test.dart';
import 'package:form_foundation/form_foundation.dart';
import 'package:material_ui/material_ui.dart';

class DummyFieldState {
  DummyFieldState(this.text);
  final String text;
}

class DummyEntry implements MapFieldEntry<DummyFieldState> {
  DummyEntry(this.state);
  @override
  final DummyFieldState state;
}

class MockHandler implements FieldHandler<DummyFieldState, String, String> {
  @override
  Widget buildField({
    required BuildContext context,
    required DummyFieldState fieldState,
    required String displayContext,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      initialValue: fieldState.text,
      onChanged: onChanged,
      decoration: InputDecoration(hintText: displayContext),
    );
  }
}

class MockRegistry extends FieldHandlerRegistry<DummyFieldState, String, MockHandler> {
  final handler = MockHandler();

  @override
  MockHandler handlerForField(DummyFieldState field) => handler;
}

void main() {
  late MockRegistry mockRegistry;

  setUp(() {
    mockRegistry = MockRegistry();
  });

  Widget buildSubject({
    required Map<String, DummyEntry> fieldStates,
    Iterable<String>? errors,
    Widget? addButton,
    void Function(String key, MockHandler handler, String value)? onChanged,
    void Function(MapEntry<String, DummyEntry>)? onRemove,
    bool Function(MapEntry<String, DummyEntry>)? testCanRemoveEntry,
    FormThemeData? theme,
    EditorGroupView view = EditorGroupView.framed,
  }) {
    Widget body = NodeEditor<String, String, DummyFieldState, DummyEntry, String, MockHandler>(
      fieldStates: fieldStates,
      handlerRegistry: mockRegistry,
      errors: errors,
      addButton: addButton,
      view: view,
      onChanged: onChanged,
      onRemove: onRemove,
      testCanRemoveEntry: testCanRemoveEntry,
      displayContextForField: (key, state) => 'Context: $key',
    );
    if (theme != null) {
      body = FormTheme(data: theme, child: body);
    }
    return MaterialApp(home: Scaffold(body: body));
  }

  group('NodeEditor Widget Tests', () {
    testWidgets('1. Displays the field list by Map keys', (tester) async {
      final fields = {
        'k1': DummyEntry(DummyFieldState('Value 1')),
        'k2': DummyEntry(DummyFieldState('Value 2')),
      };

      await tester.pumpWidget(buildSubject(fieldStates: fields));

      expect(find.text('Value 1'), findsOneWidget);
      expect(find.text('Value 2'), findsOneWidget);
    });

    testWidgets('2. Displays the error list', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          fieldStates: {},
          errors: ['Critical error', 'Second error'],
        ),
      );

      // An empty editor collapses into an InputDecorator frame; the errors
      // are merged into its errorText.
      expect(find.text('Critical error\nSecond error'), findsOneWidget);
    });

    testWidgets('3. Displays the provided add button and reacts to a click', (tester) async {
      bool addCalled = false;

      await tester.pumpWidget(
        buildSubject(
          fieldStates: {},
          addButton: IconButton(
            onPressed: () => addCalled = true,
            icon: const Icon(Icons.add),
          ),
        ),
      );

      final addButton = find.byIcon(Icons.add);
      expect(addButton, findsOneWidget);

      await tester.tap(addButton);
      await tester.pump();

      expect(addCalled, isTrue);
    });

    testWidgets('4. Calls onChanged with the key and handler on input', (tester) async {
      String? updatedKey;
      String? updatedValue;

      final fields = {
        'field_1': DummyEntry(DummyFieldState('Initial text')),
      };

      await tester.pumpWidget(
        buildSubject(
          fieldStates: fields,
          onChanged: (key, handler, value) {
            updatedKey = key;
            updatedValue = value;
          },
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'New text');
      await tester.pump();

      expect(updatedKey, equals('field_1'));
      expect(updatedValue, equals('New text'));
    });

    testWidgets('5. Checks the testCanRemoveEntry removal rule condition', (tester) async {
      MapEntry<String, DummyEntry>? removedEntry;

      final fields = {
        'removable': DummyEntry(DummyFieldState('Can be removed')),
        'readonly': DummyEntry(DummyFieldState('Cannot be removed')),
      };

      await tester.pumpWidget(
        buildSubject(
          fieldStates: fields,
          onRemove: (entry) => removedEntry = entry,
          testCanRemoveEntry: (entry) => entry.key == 'removable',
        ),
      );

      // The remove button must appear for only one element
      final removeButtons = find.byIcon(Icons.delete);
      expect(removeButtons, findsOneWidget);

      await tester.tap(removeButtons);
      await tester.pump();

      expect(removedEntry?.key, equals('removable'));
    });

    testWidgets('6. An empty framed editor with an add button stays collapsed', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          fieldStates: {},
          addButton: IconButton(
            onPressed: () {},
            icon: const Icon(Icons.add),
          ),
        ),
      );

      // The button must live in the frame's suffix, not force the frame open
      // as an in-content button row would.
      final decorator = tester.widget<InputDecorator>(find.byType(InputDecorator));
      expect(decorator.isEmpty, isTrue);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('7. An empty expanded editor displays the add button', (tester) async {
      bool addCalled = false;

      await tester.pumpWidget(
        buildSubject(
          fieldStates: {},
          view: EditorGroupView.expanded,
          addButton: IconButton(
            onPressed: () => addCalled = true,
            icon: const Icon(Icons.add),
          ),
        ),
      );

      // The expanded view has no collapsed frame with a suffix icon, so the
      // button row is the only way to fill an empty node.
      final addButton = find.byIcon(Icons.add);
      expect(addButton, findsOneWidget);

      await tester.tap(addButton);
      await tester.pump();
      expect(addCalled, isTrue);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema_form_builder/json_schema_form_builder.dart';
// The dialog host is internal (not part of the public facade); reached the
// same way ObjectField opens it.
import 'package:json_schema_form_builder/src/widgets/field_editor_screen.dart';

import 'helpers.dart';

/// The registry's cycle guard: a schema recursing through OBJECT properties
/// (`node -> next -> node`) must terminate — before the guard, state
/// building descended into it forever and hung the app. A repeated `$ref`
/// without a value collapses into a [CycleFieldState], rendered as an
/// "Expand cycle" button that reveals one level per press.
void main() {
  final directRecursion = Schema.fromMap({
    'type': 'object',
    r'$defs': {
      'node': {
        'type': 'object',
        'properties': {
          'label': {'type': 'string', 'default': 'leaf'},
          'next': {r'$ref': r'#/$defs/node'},
        },
      },
    },
    'properties': {
      'recursive': {'title': 'Recursive', r'$ref': r'#/$defs/node'},
    },
  });

  group('cycle guard in state building', () {
    test('direct object-object recursion terminates; the repeat collapses to CycleFieldState', () async {
      final registry = buildRegistry();

      final root = await buildRootState(registry, directRecursion, value: const PresenceValue.absent());

      final recursive = (root! as ObjectFieldState).children['recursive']!.state;
      // First occurrence expands normally...
      expect(recursive, isA<ObjectFieldState>());
      final next = (recursive as ObjectFieldState).children['next']!.state;
      // ...the valueless repeat one level below is collapsed.
      expect(next, isA<CycleFieldState>());
      expect((next as CycleFieldState).ref, r'#/$defs/node');
    });

    test('the guard fires at the repeat even with data; the value is passed through', () async {
      // Deliberate: the guard must not depend on the value, or the widget at
      // the repeat position would swap types on the first keystroke and kill
      // focus (see CycleField). The data renders through the widget's
      // auto-expansion; Json -> State -> Json identity holds because the
      // value is carried by the cycle state.
      final registry = buildRegistry();

      final root = await buildRootState(
        registry,
        directRecursion,
        value: const PresenceValue({
          'recursive': {
            'label': 'a',
            'next': {'label': 'b'},
          },
        }),
      );

      final recursive = (root! as ObjectFieldState).children['recursive']!.state as ObjectFieldState;
      final next = recursive.children['next']!.state;
      expect(next, isA<CycleFieldState>());
      expect(next.valueOrNull, {'label': 'b'});
      expect(root.valueOrNull, {
        'recursive': {
          'label': 'a',
          'next': {'label': 'b'},
        },
      });
    });

    test('an indirect cycle (a -> b -> a) terminates too', () async {
      final registry = buildRegistry();
      final schema = Schema.fromMap({
        'type': 'object',
        r'$defs': {
          'a': {
            'type': 'object',
            'properties': {
              'toB': {r'$ref': r'#/$defs/b'},
            },
          },
          'b': {
            'type': 'object',
            'properties': {
              'toA': {r'$ref': r'#/$defs/a'},
            },
          },
        },
        'properties': {
          'start': {r'$ref': r'#/$defs/a'},
        },
      });

      final root = await buildRootState(registry, schema, value: const PresenceValue.absent());

      final start = (root! as ObjectFieldState).children['start']!.state as ObjectFieldState;
      final toB = start.children['toB']!.state as ObjectFieldState;
      expect(toB.children['toA']!.state, isA<CycleFieldState>());
    });
  });

  group('CycleField widget: lazy expansion', () {
    // The collapsed cycle row is an icon-only button; the action name lives
    // in its tooltip (see CycleField).
    final expandButton = find.byIcon(Icons.unfold_more);

    Widget harness(Widget child) {
      return MaterialApp(
        localizationsDelegates: JsonFormLocalizations.localizationsDelegates,
        supportedLocales: JsonFormLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );
    }

    testWidgets('each press on "Expand cycle" reveals exactly one more level', (tester) async {
      await tester.pumpWidget(harness(JsonSchemaForm(schema: directRecursion)));
      await tester.pumpAndSettle();

      // Level 1 is expanded eagerly, the level-2 repeat is collapsed.
      expect(expandButton, findsOneWidget);

      final labelFields = find.widgetWithText(TextField, 'label');
      expect(labelFields, findsOneWidget);

      await tester.tap(expandButton);
      await tester.pumpAndSettle();

      // Level 2 expanded: its label editor appeared, and the level-3 repeat
      // collapsed into a new button.
      expect(find.widgetWithText(TextField, 'label'), findsNWidgets(2));
      expect(expandButton, findsOneWidget);
    });

    testWidgets('existing data auto-expands without pressing the button', (tester) async {
      await tester.pumpWidget(
        harness(
          JsonSchemaForm(
            schema: directRecursion,
            initialValue: const PresenceValue({
              'recursive': {
                'label': 'a',
                'next': {'label': 'b'},
              },
            }),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Both data levels are visible without any interaction...
      expect(find.text('a'), findsOneWidget);
      expect(find.text('b'), findsOneWidget);
      // ...and the valueless repeat below the data stays collapsed.
      expect(expandButton, findsOneWidget);
    });

    testWidgets('a schema edit rebuilds expanded levels in place, without collapsing them', (tester) async {
      // Editing the schema (e.g. typing in a schema editor) re-derives the
      // whole state tree. The cycle wrapper must keep its expanded subtree
      // rendered through the async rebuild: clearing it would collapse every
      // level to the button row and re-expand them one async hop at a time —
      // a visible jerk on every keystroke.
      const value = PresenceValue({
        'recursive': {
          'label': 'a',
          'next': {
            'label': 'b',
            'next': {'label': 'c'},
          },
        },
      });

      await tester.pumpWidget(harness(JsonSchemaForm(schema: directRecursion, initialValue: value)));
      await tester.pumpAndSettle();
      expect(find.text('c'), findsOneWidget);

      // A schema edit that changes the recursive node's definition.
      final editedSchema = Schema.fromMap({
        ...directRecursion.value,
        r'$defs': {
          'node': {
            'type': 'object',
            'properties': {
              'label': {'type': 'string', 'title': 'Label v2', 'default': 'leaf'},
              'next': {r'$ref': r'#/$defs/node'},
            },
          },
        },
      });
      await tester.pumpWidget(harness(JsonSchemaForm(schema: editedSchema, initialValue: value)));

      // Pump frame by frame until the rebuild settles: the deepest expanded
      // level must stay on screen the whole time.
      for (var i = 0; i < 50; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        expect(find.text('c'), findsOneWidget, reason: 'expanded level collapsed during the rebuild (frame $i)');
        if (!tester.binding.hasScheduledFrame) break;
      }

      // The rebuild converged on the edited schema with the expansion kept:
      // all three levels show the renamed label field.
      expect(find.widgetWithText(TextField, 'Label v2'), findsNWidgets(3));
      expect(find.text('c'), findsOneWidget);
    });

    testWidgets('typing into a freshly expanded level keeps focus across the host rebuild', (tester) async {
      await tester.pumpWidget(harness(JsonSchemaForm(schema: directRecursion)));
      await tester.pumpAndSettle();

      await tester.tap(expandButton);
      await tester.pumpAndSettle();

      final innerLabel = find.widgetWithText(TextField, 'label').last;
      await tester.enterText(innerLabel, 'i');
      // The first character triggers a host rebuild from the new value; the
      // cycle wrapper must keep the widget type at its position stable so
      // the editing element (and its focus) survives.
      await tester.pumpAndSettle();

      final editable = tester.state<EditableTextState>(
        find.descendant(of: find.widgetWithText(TextField, 'label').last, matching: find.byType(EditableText)),
      );
      expect(editable.widget.focusNode.hasFocus, isTrue);
      expect(editable.widget.controller.text, 'i');
    });

    testWidgets('typing into the SECOND expanded level keeps focus on every character', (tester) async {
      // Regression: edits travel up THROUGH the outer CycleField. Every
      // cycle position must keep its widget type across the rebuilds, which
      // holds because a CycleField pushes a CycleFieldState upward (not its
      // raw expanded subtree) — otherwise the outer level would render the
      // real editor at the nested position and the next pipeline rebuild
      // would collapse it back, recreating the element per keystroke.
      await tester.pumpWidget(harness(JsonSchemaForm(schema: directRecursion)));
      await tester.pumpAndSettle();

      await tester.tap(expandButton);
      await tester.pumpAndSettle();
      await tester.tap(expandButton);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'label'), findsNWidgets(3));

      EditableTextState innermostEditable() => tester.state<EditableTextState>(
        find.descendant(of: find.widgetWithText(TextField, 'label').last, matching: find.byType(EditableText)),
      );

      await tester.enterText(find.widgetWithText(TextField, 'label').last, 'x');
      await tester.pumpAndSettle();
      expect(innermostEditable().widget.focusNode.hasFocus, isTrue, reason: 'focus lost after the first character');
      expect(innermostEditable().widget.controller.text, 'x');

      // The second character must land in the SAME still-focused field.
      await tester.enterText(find.widgetWithText(TextField, 'label').last, 'xy');
      await tester.pumpAndSettle();
      expect(innermostEditable().widget.focusNode.hasFocus, isTrue, reason: 'focus lost after the second character');
      expect(innermostEditable().widget.controller.text, 'xy');
    });

    testWidgets('inside a dialog host that renders pushed states, focus survives every character', (tester) async {
      // FieldEditorScreen (the object edit dialog) renders the states pushed
      // by onChanged directly — unlike JsonSchemaForm, which only extracts
      // the value and rebuilds through the pipeline. If CycleField pushed its
      // raw expanded subtree, the dialog would show the real editor at the
      // cycle position and the widget type would flip, killing focus.
      final registry = buildRegistry();
      final root = (await buildRootState(registry, directRecursion, value: const PresenceValue.absent()))!;

      await tester.pumpWidget(
        harness(
          FieldEditorScreen(
            initState: root,
            registry: registry,
            displayContext: FieldDisplayContext.root(formState: root),
            fieldTitle: 'Recursive',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(expandButton);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'label'), findsNWidgets(2));

      EditableTextState innermostEditable() => tester.state<EditableTextState>(
        find.descendant(of: find.widgetWithText(TextField, 'label').last, matching: find.byType(EditableText)),
      );

      await tester.enterText(find.widgetWithText(TextField, 'label').last, 'x');
      await tester.pumpAndSettle();
      expect(innermostEditable().widget.focusNode.hasFocus, isTrue, reason: 'focus lost after the first character');
      expect(innermostEditable().widget.controller.text, 'x');

      await tester.enterText(find.widgetWithText(TextField, 'label').last, 'xy');
      await tester.pumpAndSettle();
      expect(innermostEditable().widget.focusNode.hasFocus, isTrue, reason: 'focus lost after the second character');
      expect(innermostEditable().widget.controller.text, 'xy');
    });

    testWidgets('a cycle inside a oneOf branch of an array item keeps focus on every character', (tester) async {
      // Repro of the demo scenario: Recursive References -> add a child ->
      // switch the variant to the recursive branch -> expand -> type into
      // "name". The cycle sits BELOW a VariantSwitcher inside an array item.
      final treeSchema = Schema.fromMap({
        'definitions': {
          'node': {
            'type': 'object',
            'properties': {
              'name': {'type': 'string'},
              'children': {
                'type': 'array',
                'items': {
                  'oneOf': [
                    {'title': 'None', 'type': 'null'},
                    {r'$ref': '#/definitions/node'},
                  ],
                },
              },
            },
          },
        },
        'type': 'object',
        'properties': {
          'tree': {'title': 'Recursive references', r'$ref': '#/definitions/node'},
        },
      });

      await tester.pumpWidget(
        harness(
          JsonSchemaForm(
            schema: treeSchema,
            // Inline arrays, as in the demo: the item's variant dropdown
            // renders in the main form instead of behind an edit dialog.
            registry: standardJsonHandlerRegistry(arrayInline: true),
            initialValue: const PresenceValue({
              'tree': {
                'children': [null],
              },
            }),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch the item's variant from "None" to the recursive branch.
      await tester.tap(find.byType(DropdownButton<int>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Option 2').last);
      await tester.pumpAndSettle();

      // The recursive branch collapses into the cycle row; expand it.
      await tester.tap(expandButton.last);
      await tester.pumpAndSettle();

      final nameFields = find.widgetWithText(TextField, 'name');
      expect(nameFields, findsNWidgets(2), reason: 'outer node + expanded branch node');

      EditableTextState innermostEditable() => tester.state<EditableTextState>(
        find.descendant(of: find.widgetWithText(TextField, 'name').last, matching: find.byType(EditableText)),
      );

      await tester.enterText(nameFields.last, 'x');
      await tester.pumpAndSettle();
      expect(innermostEditable().widget.focusNode.hasFocus, isTrue, reason: 'focus lost after the first character');
      expect(innermostEditable().widget.controller.text, 'x');

      await tester.enterText(find.widgetWithText(TextField, 'name').last, 'xy');
      await tester.pumpAndSettle();
      expect(innermostEditable().widget.focusNode.hasFocus, isTrue, reason: 'focus lost after the second character');
      expect(innermostEditable().widget.controller.text, 'xy');
    });

    testWidgets('picking the recursive (container) branch in the add dialog survives the OK', (tester) async {
      // Repro of the demo scenario: children "+" -> pick Option 2 in the add
      // dialog -> OK. The recursive branch resolves to an object, so the
      // switch must write {} (rjsf's getDefaultFormState parity, see
      // containerEmptyValue) — otherwise the committed value stays null and
      // the added item shows "None" instead of the picked branch.
      final treeSchema = Schema.fromMap({
        'definitions': {
          'node': {
            'type': 'object',
            'properties': {
              'name': {'type': 'string'},
              'children': {
                'type': 'array',
                'items': {
                  'oneOf': [
                    {'title': 'None', 'type': 'null'},
                    {r'$ref': '#/definitions/node'},
                  ],
                },
              },
            },
          },
        },
        'type': 'object',
        'properties': {
          'tree': {'title': 'Recursive references', r'$ref': '#/definitions/node'},
        },
      });

      JsonFieldState<Schema>? lastState;
      await tester.pumpWidget(
        harness(
          JsonSchemaForm(
            schema: treeSchema,
            registry: standardJsonHandlerRegistry(arrayInline: true),
            initialValue: const PresenceValue({
              'tree': {'name': 'root'},
            }),
            onChanged: (state) => lastState = state,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // "+" of the children array opens the add dialog.
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Pick the recursive branch in the dialog.
      await tester.tap(find.byType(DropdownButton<int>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Option 2').last);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'OK'));
      await tester.pumpAndSettle();

      // The picked branch materialized as {} — the item matches Option 2 on
      // the main screen instead of falling back to "None".
      expect(lastState?.valueOrNull, {
        'tree': {
          'name': 'root',
          'children': [<String, Object?>{}],
        },
      });
      expect(find.text('Option 2'), findsOneWidget);
      expect(find.text('None'), findsNothing);
    });

    testWidgets('editing a field inside the expanded level writes into the document', (tester) async {
      JsonFieldState<Schema>? lastState;
      await tester.pumpWidget(
        harness(
          JsonSchemaForm(
            schema: directRecursion,
            onChanged: (state) => lastState = state,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(expandButton);
      await tester.pumpAndSettle();

      final labelFields = find.widgetWithText(TextField, 'label');
      await tester.enterText(labelFields.last, 'inner');
      await tester.pumpAndSettle();

      expect(lastState?.valueOrNull, {
        'recursive': {
          'next': {'label': 'inner'},
        },
      });
    });
  });
}

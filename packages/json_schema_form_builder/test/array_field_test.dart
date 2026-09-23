import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema_form_builder/json_schema_form_builder.dart';

import 'helpers.dart';

void main() {
  group('tuple (positional) item schemas', () {
    // The 2020-12 dialect (the one the bundled validator understands).
    final prefixItemsSchema = {
      'type': 'array',
      'prefixItems': [
        {'type': 'string'},
        {'type': 'boolean'},
      ],
      'items': {'type': 'number'},
    };

    // The draft-07 dialect, kept for rendering compatibility only: the
    // bundled validator cannot process it.
    final draft07Schema = {
      'type': 'array',
      'items': [
        {'type': 'string'},
        {'type': 'boolean'},
      ],
      'additionalItems': {'type': 'number'},
    };

    Future<ArrayFieldState> buildTuple(Map<String, Object?> schemaMap) async {
      final registry = buildRegistry();
      final schema = Schema.fromMap(schemaMap);
      return (await buildRootState(registry, schema, value: const PresenceValue(['a', true, 5.5])))! as ArrayFieldState;
    }

    for (final (dialect, schemaMap) in [('2020-12 prefixItems/items', prefixItemsSchema), ('draft-07 items/additionalItems', draft07Schema)]) {
      test('$dialect: children follow the positional schemas, the rest the additional one', () async {
        final state = await buildTuple(schemaMap);

        expect(state.children.map((c) => c.state.runtimeType), [StringFieldState, BoolFieldState, DoubleFieldState]);
        expect(state.positionalItemSchemasForNew, hasLength(2));
        expect(state.additionalItemsSchemaForNew, isNotNull);
        // A tuple is never a multi-select.
        expect(state.itemsSchemaForEnum, isNull);
      });
    }

    test('the 2020-12 tuple form also passes the bundled validator', () async {
      // The reason the samples use prefixItems: the draft-07 form makes
      // json_schema_builder throw, which surfaces as the scary
      // "validator rejected the schema" error.
      final errors = await validateDataBySchema(Schema.fromMap(prefixItemsSchema), ['a', true, 5.5]);

      expect(errors, isEmpty);

      final typeErrors = await validateDataBySchema(Schema.fromMap(prefixItemsSchema), [5, true, 'x']);
      expect(typeErrors, isNotEmpty);
      expect(typeErrors!.any((e) => e.isValidatorRejectedSchema), isFalse);
    });
  });

  group('ArrayField add item flow', () {
    Future<JsonFieldState> buildArrayState(JsonHandlerRegistry registry, Map<String, Object?> schemaMap) async {
      final schema = Schema.fromMap(schemaMap);
      return (await buildRootState(registry, schema, value: const PresenceValue.absent()))!;
    }

    // Integer has no canonical empty value, so the dialog is its add path;
    // string items (empty string is a valid value) are appended immediately,
    // see 'a string item is appended immediately...'.
    testWidgets('the value is entered in a dialog before the item is added', (tester) async {
      final registry = buildRegistry();
      final state = await buildArrayState(registry, {
        'type': 'array',
        'items': {'type': 'integer'},
      });

      JsonFieldState? updated;
      await tester.pumpWidget(buildArrayForm(registry, state, (s) => updated = s));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // No item is appended before the dialog is confirmed.
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(updated, isNull);

      await tester.enterText(find.byType(TextField).last, '5');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'OK'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(updated, isNotNull);
      expect(updated!.valueOrNull, [5]);
    });

    testWidgets('cancelling the dialog adds nothing', (tester) async {
      final registry = buildRegistry();
      final state = await buildArrayState(registry, {
        'type': 'array',
        'items': {'type': 'integer'},
      });

      JsonFieldState? updated;
      await tester.pumpWidget(buildArrayForm(registry, state, (s) => updated = s));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(updated, isNull);
    });

    testWidgets(r'the dialog validates a $ref item schema against the root document', (tester) async {
      final registry = buildRegistry();
      final state = await buildArrayState(registry, {
        'definitions': {
          'item': {'type': 'string', 'minLength': 3},
        },
        'type': 'array',
        'items': {r'$ref': '#/definitions/item'},
      });

      JsonFieldState? updated;
      await tester.pumpWidget(buildArrayForm(registry, state, (s) => updated = s));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // The raw $ref admits no handler, so the handler is re-selected from
      // the resolved schema (string) and the dialog gets a plain text field.
      //
      // Too short for minLength taken from the root's definitions: without a
      // root-aware validation context the $ref cannot resolve at all.
      await tester.enterText(find.byType(TextField).last, 'ab');
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'OK')).onPressed, isNull);

      await tester.enterText(find.byType(TextField).last, 'abcd');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'OK'));
      await tester.pumpAndSettle();

      expect(updated, isNotNull);
      expect(updated!.valueOrNull, ['abcd']);
    });

    testWidgets('an object item seeded from property defaults is added without a dialog', (tester) async {
      final registry = buildRegistry();
      final state = await buildArrayState(registry, {
        'title': 'Array',
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'nested': {'title': 'Nested array', 'type': 'string', 'default': 'nested array default'},
          },
        },
      });

      JsonFieldState? updated;
      await tester.pumpWidget(buildArrayForm(registry, state, (s) => updated = s));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // The item schema itself has no default, but the object seeded from the
      // property defaults carries a value, so no dialog is needed.
      expect(find.byType(AlertDialog), findsNothing);
      expect(updated, isNotNull);
      expect(updated!.valueOrNull, [
        {'nested': 'nested array default'},
      ]);
    });

    testWidgets('a schema default skips the dialog and is added directly', (tester) async {
      final registry = buildRegistry();
      final state = await buildArrayState(registry, {
        'type': 'array',
        'items': {'type': 'string', 'default': 'abc'},
      });

      JsonFieldState? updated;
      await tester.pumpWidget(buildArrayForm(registry, state, (s) => updated = s));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(updated, isNotNull);
      expect(updated!.valueOrNull, ['abc']);
    });

    testWidgets('a string item is appended immediately as an empty string', (tester) async {
      final registry = buildRegistry();
      final state = await buildArrayState(registry, {
        'type': 'array',
        'items': {'type': 'string'},
      });

      JsonFieldState? updated;
      await tester.pumpWidget(buildArrayForm(registry, state, (s) => updated = s));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // The canonical empty string is a valid value for the item schema, so
      // no dialog: the item appears at once and is edited in place.
      expect(find.byType(AlertDialog), findsNothing);
      expect(updated, isNotNull);
      expect(updated!.valueOrNull, ['']);
    });

    testWidgets('prefixItems: a string slot is appended immediately, a number slot asks for a value', (tester) async {
      final registry = buildRegistry();
      final state = await buildArrayState(registry, {
        'type': 'array',
        'prefixItems': [
          {'type': 'string'},
          {'type': 'number'},
        ],
      });

      JsonFieldState? updated;
      await tester.pumpWidget(
        buildArrayForm(registry, state, (s) => updated = s),
      );
      await tester.pumpAndSettle();

      // First slot is a string: appended at once, no dialog.
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(updated!.valueOrNull, ['']);

      // Rebuild the form for the updated value the way production does.
      final schema = Schema.fromMap({
        'type': 'array',
        'prefixItems': [
          {'type': 'string'},
          {'type': 'number'},
        ],
      });
      final nextState = (await buildRootState(registry, schema, value: PresenceValue(updated!.valueOrNull)))!;
      await tester.pumpWidget(buildArrayForm(registry, nextState, (s) => updated = s));
      await tester.pumpAndSettle();

      // Second slot is a number (no canonical empty value): the dialog opens.
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('an empty string rejected by the item schema still goes through the dialog', (tester) async {
      final registry = buildRegistry();
      final state = await buildArrayState(registry, {
        'type': 'array',
        'items': {'type': 'string', 'minLength': 3},
      });

      JsonFieldState? updated;
      await tester.pumpWidget(buildArrayForm(registry, state, (s) => updated = s));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // '' fails minLength, so appending it silently would put an invalid
      // item into the document; the dialog asks for a valid value instead.
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(updated, isNull);
    });
  });

  group('EnumArrayField frame', () {
    testWidgets('the multi-select frame follows the EditorGroup border mechanics', (tester) async {
      final registry = buildRegistry();
      final schema = Schema.fromMap({
        'type': 'array',
        'uniqueItems': true,
        'items': {
          'type': 'string',
          'enum': ['a', 'b'],
        },
      });
      final state = (await buildRootState(registry, schema, value: const PresenceValue(['a'])))!;

      // No inputDecorationTheme configured: like EditorGroup, the frame must
      // fall back to an OutlineInputBorder instead of the underline of a
      // bare InputDecorator.
      await tester.pumpWidget(buildArrayForm(registry, state, (_) {}));
      await tester.pumpAndSettle();

      final decorator = tester.widget<InputDecorator>(find.byType(InputDecorator));
      expect(decorator.decoration.border, isA<OutlineInputBorder>());
      // The decorator draws only the frame and the indented label; the
      // checkbox list is stacked on top of it with no horizontal inset.
      expect(decorator.decoration.contentPadding, const EdgeInsetsDirectional.only(start: 12));
      expect(decorator.expands, isTrue);
    });
  });

  group('EnumArrayField out-of-enum values', () {
    testWidgets('a value missing from the enum is shown and can be removed', (tester) async {
      final registry = buildRegistry();
      final schema = Schema.fromMap({
        'type': 'array',
        'uniqueItems': true,
        'items': {
          'type': 'string',
          'enum': ['a', 'b', 'c'],
        },
      });

      final state = (await buildRootState(registry, schema, value: const PresenceValue(['a', 'x'])))!;

      JsonFieldState? updated;
      await tester.pumpWidget(buildArrayForm(registry, state, (s) => updated = s));
      await tester.pumpAndSettle();

      // Before the fix only the 3 enum entries were listed and 'x' (with its
      // validation errors) was invisible and impossible to get rid of.
      expect(find.byType(CheckboxListTile), findsNWidgets(4));
      expect(find.text('x'), findsOneWidget);

      final extraTile = tester.widget<CheckboxListTile>(
        find.ancestor(of: find.text('x'), matching: find.byType(CheckboxListTile)),
      );
      expect(extraTile.value, isTrue);
      expect(extraTile.onChanged, isNotNull);

      // Unchecking the extra value removes it from the document. The extra
      // entry sits at the end of the height-capped inner ListView, so scroll
      // it into view first.
      await tester.ensureVisible(find.text('x'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('x'));
      await tester.pumpAndSettle();

      expect(updated, isNotNull);
      expect(updated!.valueOrNull, ['a']);
    });

    testWidgets('uniqueItems + anyOf of pinned alternatives renders as a multi-select', (tester) async {
      final registry = buildRegistry();
      final schema = Schema.fromMap({
        'title': 'Color mask',
        'type': 'array',
        'uniqueItems': true,
        'items': {
          'title': 'Color',
          'type': 'string',
          'anyOf': [
            {
              'type': 'string',
              'enum': ['#ff0000'],
              'title': 'Red',
            },
            {
              'type': 'string',
              'enum': ['#00ff00'],
              'title': 'Green',
            },
            {
              'type': 'string',
              'enum': ['#0000ff'],
              'title': 'Blue',
            },
          ],
        },
      });

      final state = (await buildRootState(registry, schema, value: const PresenceValue(['#ff0000'])))!;

      JsonFieldState? updated;
      await tester.pumpWidget(buildArrayForm(registry, state, (s) => updated = s));
      await tester.pumpAndSettle();

      // rjsf's isMultiSelect: unique items whose alternatives all pin their
      // value render as checkboxes labelled with the alternative titles, not
      // as a list editor with variant switchers.
      expect(find.byType(CheckboxListTile), findsNWidgets(3));
      expect(find.byType(DropdownButton<int>), findsNothing);
      expect(find.text('Red'), findsOneWidget);
      expect(find.text('Green'), findsOneWidget);
      expect(find.text('Blue'), findsOneWidget);

      final redTile = tester.widget<CheckboxListTile>(
        find.ancestor(of: find.text('Red'), matching: find.byType(CheckboxListTile)),
      );
      expect(redTile.value, isTrue);

      await tester.tap(find.text('Green'));
      await tester.pumpAndSettle();

      expect(updated, isNotNull);
      expect(updated!.valueOrNull, ['#ff0000', '#00ff00']);
    });

    testWidgets(r'an items schema behind a $ref still renders as a multi-select', (tester) async {
      final registry = buildRegistry();
      final schema = Schema.fromMap({
        'definitions': {
          'Color': {
            'title': 'Color',
            'type': 'string',
            'anyOf': [
              {
                'type': 'string',
                'enum': ['#ff0000'],
                'title': 'Red',
              },
              {
                'type': 'string',
                'enum': ['#00ff00'],
                'title': 'Green',
              },
              {
                'type': 'string',
                'enum': ['#0000ff'],
                'title': 'Blue',
              },
            ],
          },
        },
        'type': 'object',
        'properties': {
          'colorMask': {
            'type': 'array',
            'uniqueItems': true,
            'items': {r'$ref': '#/definitions/Color'},
            'title': 'Color mask',
          },
        },
      });

      final state = (await buildRootState(
        registry,
        schema,
        value: const PresenceValue({
          'colorMask': ['#ff0000'],
        }),
      ))!;

      JsonFieldState? updated;
      await tester.pumpWidget(buildArrayForm(registry, state, (s) => updated = s));
      await tester.pumpAndSettle();

      // The raw items schema is just the $ref: the multi-select detection must
      // look at the schema resolved against the validation context.
      expect(find.byType(CheckboxListTile), findsNWidgets(3));
      expect(find.text('Red'), findsOneWidget);

      await tester.tap(find.text('Blue'));
      await tester.pumpAndSettle();

      expect(updated, isNotNull);
      expect(updated!.valueOrNull, {
        'colorMask': ['#ff0000', '#0000ff'],
      });
    });
  });

  group('variant switch on an array item', () {
    testWidgets('an object item switched to a branch with no values becomes {}, not null', (tester) async {
      final registry = buildRegistry();
      final schema = Schema.fromMap({
        'type': 'array',
        'items': {
          'type': 'object',
          'anyOf': [
            {
              'properties': {
                'foo': {'type': 'string'},
              },
            },
            {
              'properties': {
                'bar': {'type': 'string'},
              },
            },
          ],
        },
      });

      final state = (await buildRootState(
        registry,
        schema,
        value: const PresenceValue([
          {'foo': 'x'},
        ]),
      ))!;

      JsonFieldState? updated;
      await tester.pumpWidget(buildArrayForm(registry, state, (s) => updated = s));
      await tester.pumpAndSettle();

      // The item's Variant switcher: pick the second alternative.
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Option 2').last);
      await tester.pumpAndSettle();

      // An array item cannot be absent; before the fix the emptied item
      // degraded to null (invalid against the object item schema).
      expect(updated, isNotNull);
      expect(updated!.valueOrNull, [<String, Object?>{}]);
    });
  });
}

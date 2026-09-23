import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:json_schema_form_builder/json_schema_form_builder.dart';
import 'package:json_schema_form_builder/src/handlers/object/object_entry_edit_dialog.dart';
import 'package:json_schema_form_builder/src/handlers/object/object_entry_edit_dialog_snapshot.dart';

import 'helpers.dart';

void main() {
  group('entry edit dialog seeds the canonical empty value', () {
    Future<(FieldDisplayContext, EntryEditorSnapshot)> buildSnapshot(JsonHandlerRegistry registry) async {
      final rootSchema = Schema.fromMap({'type': 'object', 'additionalProperties': true});
      final rootState = (await buildRootState(registry, rootSchema, value: const PresenceValue(<String, Object?>{})))!;
      final displayContext = FieldDisplayContext.root(formState: rootState);

      final snapshot = await EntryEditorSnapshot.build(
        schema: rootSchema as ObjectSchema,
        key: 'newKey',
        displayContext: displayContext,
        handlerRegistry: registry,
        additionalPropertiesAllowed: true,
        fieldNamePatterns: const {},
      );
      return (displayContext, snapshot!);
    }

    Future<EntryEditorSnapshot> switchToHandler(JsonHandlerRegistry registry, Type handlerType) async {
      final (displayContext, snapshot) = await buildSnapshot(registry);
      final binding = snapshot.availableHandlers.firstWhere((b) => b.fieldHandler.runtimeType == handlerType);
      return snapshot.applyHandler(
        handler: binding,
        displayContext: displayContext,
        handlerRegistry: registry,
      );
    }

    test('switching to the array type yields [], not null', () async {
      final registry = buildRegistry();

      final snapshot = await switchToHandler(registry, ArrayFieldHandler);

      expect(snapshot.fieldState!.valueOrNull, <Object?>[]);
    });

    test('switching to the object type yields {}, not null', () async {
      final registry = buildRegistry();

      final snapshot = await switchToHandler(registry, ObjectFieldHandler);

      expect(snapshot.fieldState!.valueOrNull, <String, Object?>{});
    });

    test('switching to the string type yields an empty string', () async {
      final registry = buildRegistry();

      final snapshot = await switchToHandler(registry, StringFieldHandler);

      expect(snapshot.fieldState!.valueOrNull, '');
    });

    test('switching to the null type writes an explicit null, not an absent value', () async {
      final registry = buildRegistry();

      final snapshot = await switchToHandler(registry, NullFieldHandler);

      // Regression: without NullFieldHandler.canonicalEmptyValue the unified
      // switch policy seeded nothing, the state carried an absent value and
      // committing the dialog could not write the selected JSON null.
      expect(snapshot.fieldState!.hasValue, isTrue);
      expect(snapshot.fieldState!.value.valueOrNull, isNull);
    });

    test('scalars without a canonical empty value stay empty', () async {
      final registry = buildRegistry();

      final snapshot = await switchToHandler(registry, IntFieldHandler);

      expect(snapshot.fieldState!.valueOrNull, isNull);
    });

    Future<void> pumpDialog(WidgetTester tester, JsonHandlerRegistry registry) async {
      final rootSchema = Schema.fromMap({'type': 'object', 'additionalProperties': true});
      final rootState = (await buildRootState(registry, rootSchema, value: const PresenceValue(<String, Object?>{})))!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ObjectEntryEditDialog(
              handlerRegistry: registry,
              displayContext: FieldDisplayContext.root(formState: rootState),
              fieldNamePatterns: const {},
              existingKey: 'k',
              schema: rootSchema as ObjectSchema,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    bool okEnabled(WidgetTester tester) => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'OK')).onPressed != null;

    Future<void> selectType(WidgetTester tester, String typeName) async {
      await tester.tap(find.byType(DropdownButton<FieldHandlerBinding>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(typeName).last);
      await tester.pumpAndSettle();
    }

    for (final (typeName, expectEnabled) in [
      ('Array', true),
      ('Object', true),
      ('String', true),
      ('Null', true),
      ('Bool', false),
      ('Int', false),
      ('Double', false),
    ]) {
      testWidgets('OK is ${expectEnabled ? 'enabled' : 'disabled'} for an empty $typeName value', (tester) async {
        final registry = buildRegistry();
        await pumpDialog(tester, registry);

        await selectType(tester, typeName);

        expect(okEnabled(tester), expectEnabled, reason: 'empty $typeName');
      });
    }

    testWidgets('OK follows the Raw editor: valid JSON enables, invalid disables', (tester) async {
      final registry = buildRegistry();
      await pumpDialog(tester, registry);

      await selectType(tester, 'Raw');
      final rawField = find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == '[1, 2, 3]');

      await tester.enterText(rawField, '{"a": 1}');
      await tester.pumpAndSettle();
      expect(okEnabled(tester), isTrue, reason: 'valid JSON');

      // Regression: invalid text left the state holding the last valid value,
      // so OK stayed enabled and committed a value the user no longer saw.
      await tester.enterText(rawField, '{"a": ');
      await tester.pumpAndSettle();
      expect(okEnabled(tester), isFalse, reason: 'invalid JSON typed over a valid value');

      await tester.enterText(rawField, '{"a": 2}');
      await tester.pumpAndSettle();
      expect(okEnabled(tester), isTrue, reason: 'fixed JSON re-enables OK');
    });

    testWidgets('the Raw editor commits an explicit JSON null', (tester) async {
      final registry = buildRegistry();
      await pumpDialog(tester, registry);

      await selectType(tester, 'Raw');
      final rawField = find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == '[1, 2, 3]');

      // Regression: the null-submit gate used to consult the handler's type
      // claims (empty for the raw editor), so a typed `null` literal kept OK
      // disabled although the editor held a perfectly valid value.
      await tester.enterText(rawField, 'null');
      await tester.pumpAndSettle();
      expect(okEnabled(tester), isTrue, reason: 'JSON literal null is a valid raw value');
    });

    test('a schema default wins over the canonical empty value', () async {
      final registry = buildRegistry();
      final rootSchema = Schema.fromMap({
        'type': 'object',
        'properties': {
          'tags': {
            'type': 'array',
            'default': ['a'],
          },
        },
      });
      final rootState = (await buildRootState(registry, rootSchema, value: const PresenceValue(<String, Object?>{})))!;

      final snapshot = await EntryEditorSnapshot.build(
        schema: rootSchema as ObjectSchema,
        key: 'tags',
        displayContext: FieldDisplayContext.root(formState: rootState),
        handlerRegistry: registry,
        additionalPropertiesAllowed: false,
        fieldNamePatterns: const {},
      );

      expect(snapshot!.fieldState!.valueOrNull, ['a']);
    });
  });
}

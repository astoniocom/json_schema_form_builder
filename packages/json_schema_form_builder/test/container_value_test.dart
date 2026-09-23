import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema_form_builder/json_schema_form_builder.dart';

import 'helpers.dart';

void main() {
  group('ObjectFieldHandler.buildState value preservation', () {
    test('property declared only in an anyOf branch stays in the value', () async {
      final registry = buildRegistry();
      final schema = Schema.fromMap({
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
      });

      final state = await buildRootState(registry, schema, value: const PresenceValue({'bar': 'test'}));

      expect(state, isA<ObjectFieldState>());
      // Before the fix the value collapsed to {}: 'bar' is "additional" from
      // the parent schema's point of view and was dropped by the display
      // filter, and value was rebuilt from the filtered children.
      expect(state!.valueOrNull, {'bar': 'test'});
    });

    test('extra key hidden by the additional-properties policy stays in the value', () async {
      final registry = buildRegistry();
      final schema = Schema.fromMap({'type': 'object'});

      final state = await buildRootState(registry, schema, value: const PresenceValue({'bar': 'test'}));

      expect(state, isA<ObjectFieldState>());
      final objectState = state! as ObjectFieldState;
      // The display policy still hides the field itself...
      expect(objectState.children, isEmpty);
      // ...but must not destroy the data.
      expect(objectState.valueOrNull, {'bar': 'test'});
    });

    test('explicit empty object is preserved', () async {
      final registry = buildRegistry();
      final schema = Schema.fromMap({'type': 'object'});

      final state = await buildRootState(registry, schema, value: const PresenceValue(<String, dynamic>{}));

      expect(state!.valueOrNull, isEmpty);
      expect(state.hasValue, isTrue);
    });

    test('absent value stays absent', () async {
      final registry = buildRegistry();
      final schema = Schema.fromMap({'type': 'object'});

      final state = await buildRootState(registry, schema, value: const PresenceValue.absent());

      expect(state!.hasValue, isFalse);
    });
  });

  group('ArrayFieldHandler.buildState value preservation', () {
    test('items whose object schema declares properties only in anyOf branches keep their values', () async {
      final registry = buildRegistry();
      // The array value is rebuilt from children states, so a value-destroying
      // bug in a nested handler (the ObjectFieldHandler anyOf case) propagates
      // to the array. This guards the whole chain.
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

      final state = await buildRootState(
        registry,
        schema,
        value: const PresenceValue([
          {'bar': 'test'},
        ]),
      );

      expect(state, isA<ArrayFieldState>());
      expect(state!.valueOrNull, [
        {'bar': 'test'},
      ]);
    });

    test('array-level anyOf does not affect item values', () async {
      final registry = buildRegistry();
      final schema = Schema.fromMap({
        'type': 'array',
        'anyOf': [
          {
            'items': {'type': 'string'},
          },
          {
            'items': {'type': 'integer'},
          },
        ],
      });

      final state = await buildRootState(registry, schema, value: const PresenceValue(['test']));

      expect(state, isA<ArrayFieldState>());
      expect(state!.valueOrNull, ['test']);
    });

    test('explicit empty list is preserved', () async {
      final registry = buildRegistry();
      final schema = Schema.fromMap({'type': 'array'});

      final state = await buildRootState(registry, schema, value: const PresenceValue(<dynamic>[]));

      expect(state!.hasValue, isTrue);
      expect(state.valueOrNull, isEmpty);
    });
  });

  group('ObjectFieldState.applyNewChildren value merging', () {
    test('editing a visible child keeps keys declared only in anyOf branches', () async {
      final registry = buildRegistry();
      final schema = Schema.fromMap({
        'type': 'object',
        'properties': {
          'age': {'type': 'integer', 'title': 'Age'},
        },
        'anyOf': [
          {
            'title': 'First method of identification',
            'properties': {
              'firstName': {'type': 'string', 'title': 'First name'},
              'lastName': {'type': 'string', 'title': 'Last name'},
            },
          },
          {
            'title': 'Second method of identification',
            'properties': {
              'idCode': {'type': 'string', 'title': 'ID code'},
            },
          },
        ],
      });

      final state = (await buildRootState(registry, schema, value: const PresenceValue({'idCode': 'x'})))! as ObjectFieldState;

      // idCode is hidden from the root children (declared only in an anyOf
      // branch), so this reproduces the "entering age wipes idCode" bug.
      final ageState = state.children['age']!.state.copyWith(value: const PresenceValue(30));
      final updated = state.applyChildValueChange(
        key: 'age',
        newValue: ageState,
        emptyValue: const PresenceValue.absent(),
      );

      expect(updated.valueOrNull, {'idCode': 'x', 'age': 30});
    });

    test('clearing a visible child removes only its own key', () async {
      final registry = buildRegistry();
      final schema = Schema.fromMap({
        'type': 'object',
        'properties': {
          'age': {'type': 'integer'},
        },
        'anyOf': [
          {
            'properties': {
              'idCode': {'type': 'string'},
            },
          },
        ],
      });

      final state = (await buildRootState(registry, schema, value: const PresenceValue({'age': 25, 'idCode': 'x'})))! as ObjectFieldState;

      final updated = state.applyChildValueChange(
        key: 'age',
        newValue: state.children['age']!.state.clear(),
        emptyValue: const PresenceValue.absent(),
      );

      expect(updated.valueOrNull, {'idCode': 'x'});
    });
  });

  group('clearing an array item keeps the item', () {
    testWidgets('an object item emptied by clearing its variant field becomes {}, not null', (tester) async {
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

      await tester.enterText(find.widgetWithText(TextField, 'x'), '');
      await tester.pumpAndSettle();

      // Clearing the branch's only field empties the object; the item must
      // stay an (empty) object rather than degrade to null.
      expect(updated, isNotNull);
      expect(updated!.valueOrNull, [<String, Object?>{}]);
    });

    testWidgets('a cleared string item becomes an empty string', (tester) async {
      final registry = buildRegistry();
      final schema = Schema.fromMap({
        'type': 'array',
        'items': {'type': 'string'},
      });

      final state = (await buildRootState(registry, schema, value: const PresenceValue(['hello'])))!;

      JsonFieldState? updated;
      await tester.pumpWidget(buildArrayForm(registry, state, (s) => updated = s));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'hello'), '');
      await tester.pumpAndSettle();

      expect(updated, isNotNull);
      expect(updated!.valueOrNull, ['']);
    });

    testWidgets('a cleared number item keeps the previous document value', (tester) async {
      final registry = buildRegistry();
      final schema = Schema.fromMap({
        'type': 'array',
        'items': {'type': 'integer'},
      });

      final state = (await buildRootState(registry, schema, value: const PresenceValue([5])))!;

      JsonFieldState? updated;
      await tester.pumpWidget(buildArrayForm(registry, state, (s) => updated = s));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, '5'), '');
      await tester.pumpAndSettle();

      // A number has no empty JSON representation: the write is dropped and
      // emptiness stays local to the widget.
      expect(updated, isNull);
    });
  });

  group('an emptied container stays in the document', () {
    testWidgets('clearing the only declared property leaves {}, not null', (tester) async {
      final registry = buildRegistry();
      final schema = Schema.fromMap({
        'type': 'object',
        'properties': {
          'bar': {'type': 'string'},
        },
      });

      final state = (await buildRootState(registry, schema, value: const PresenceValue({'bar': 'x'})))!;

      JsonFieldState? updated;
      await tester.pumpWidget(buildArrayForm(registry, state, (s) => updated = s));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'x'), '');
      await tester.pumpAndSettle();

      // The declared key legitimately leaves the document, but the object
      // itself must not collapse into absent/null (rjsf keeps {} too).
      expect(updated, isNotNull);
      expect(updated!.value.present, isTrue);
      expect(updated!.valueOrNull, <String, Object?>{});
    });

    testWidgets('removing the last array item leaves [], not null', (tester) async {
      final registry = buildRegistry();
      final schema = Schema.fromMap({
        'type': 'array',
        'items': {'type': 'string'},
      });

      final state = (await buildRootState(registry, schema, value: const PresenceValue(['hello'])))!;

      JsonFieldState? updated;
      await tester.pumpWidget(buildArrayForm(registry, state, (s) => updated = s));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete));
      await tester.pumpAndSettle();

      expect(updated, isNotNull);
      expect(updated!.value.present, isTrue);
      expect(updated!.valueOrNull, <Object?>[]);
    });
  });

  group('clearing an additional property keeps it in the document', () {
    Future<ObjectFieldState> buildObjectState(
      JsonHandlerRegistry registry,
      Map<String, Object?> schemaMap,
      Map<String, Object?> value,
    ) async {
      final schema = Schema.fromMap(schemaMap);
      return (await buildRootState(registry, schema, value: PresenceValue(value)))! as ObjectFieldState;
    }

    const additionalOnlySchema = {'type': 'object', 'additionalProperties': true};

    JsonFieldState clearedChild(ObjectFieldState state, String key) => state.children[key]!.state.copyWith(value: const PresenceValue.absent());

    testWidgets('a cleared string becomes an empty string', (tester) async {
      final registry = buildRegistry();
      final state = await buildObjectState(registry, additionalOnlySchema, {'note': 'hello'});

      JsonFieldState? updated;
      await tester.pumpWidget(buildArrayForm(registry, state, (s) => updated = s));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'hello'), '');
      await tester.pumpAndSettle();

      // Before the fix the whole property vanished, typed-in key included.
      expect(updated, isNotNull);
      expect(updated!.valueOrNull, {'note': ''});
    });

    testWidgets('a cleared number keeps the previous document value', (tester) async {
      final registry = buildRegistry();
      final state = await buildObjectState(registry, additionalOnlySchema, {'count': 5});

      JsonFieldState? updated;
      await tester.pumpWidget(buildArrayForm(registry, state, (s) => updated = s));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, '5'), '');
      await tester.pumpAndSettle();

      // A number has no empty JSON representation, and writing null would
      // reselect NullFieldHandler on rebuild (a dead end for the field), so
      // the write is dropped entirely: emptiness stays local to the widget.
      expect(updated, isNull);
    });

    test('handlers of string/object/array types define an empty representation, scalars do not', () {
      final registry = buildRegistry();

      final stringEmpty = StringFieldHandler(registryGetter: () => registry).canonicalEmptyValue;
      expect(stringEmpty?.valueOrNull, '');

      final objectEmpty = ObjectFieldHandler(registryGetter: () => registry, displayMode: ObjectFieldDisplayMode.all).canonicalEmptyValue;
      expect(objectEmpty?.valueOrNull, <String, Object?>{});

      final arrayEmpty = ArrayFieldHandler(registryGetter: () => registry).canonicalEmptyValue;
      expect(arrayEmpty?.valueOrNull, <Object?>[]);

      expect(IntFieldHandler(registryGetter: () => registry).canonicalEmptyValue, isNull);
      expect(DoubleFieldHandler(registryGetter: () => registry).canonicalEmptyValue, isNull);
      expect(BoolFieldHandler(registryGetter: () => registry).canonicalEmptyValue, isNull);
    });

    test('a cleared schema-declared property is still removed from the value', () async {
      final registry = buildRegistry();
      final state = await buildObjectState(
        registry,
        {
          'type': 'object',
          'properties': {
            'name': {'type': 'string'},
          },
          'additionalProperties': true,
        },
        {'name': 'x'},
      );

      final updated = state.applyChildValueChange(
        key: 'name',
        newValue: clearedChild(state, 'name'),
        emptyValue: const PresenceValue.absent(),
      );

      // A schema-declared row does not depend on the key being present, so
      // clearing legitimately drops the key from the document (and the
      // now-empty object collapses into the configured emptyValue).
      expect(updated.value.present, isFalse);
      expect(updated.children.containsKey('name'), isTrue);
    });
  });
}

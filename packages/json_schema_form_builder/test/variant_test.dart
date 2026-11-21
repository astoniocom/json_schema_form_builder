import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema_form_builder/json_schema_form_builder.dart';
import 'package:json_schema_form_builder/src/models/type_matching.dart' show synthesizedTypeBranchSchemas;
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

void main() {
  group('switchRepresentationValue: the single switch policy of both UIs', () {
    test('a pinned value overrides the current one', () {
      final result = switchRepresentationValue(
        targetSchema: Schema.fromMap({'const': 'pinned'}),
        currentValue: const PresenceValue('old'),
      );
      expect(result.valueOrNull, 'pinned');
    });

    test('a single-element enum pins like const', () {
      final result = switchRepresentationValue(
        targetSchema: Schema.fromMap({
          'enum': ['only'],
        }),
        currentValue: const PresenceValue.absent(),
      );
      expect(result.valueOrNull, 'only');
    });

    test('the null type pins like const: null — switching to it writes null', () {
      final result = switchRepresentationValue(
        targetSchema: Schema.fromMap({'type': 'null', 'title': 'None'}),
        currentValue: const PresenceValue.absent(),
      );
      expect(result.present, isTrue);
      expect(result.valueOrNull, isNull);
    });

    test('a pinned value rejected by admits falls through to emptySeed', () {
      final result = switchRepresentationValue(
        targetSchema: Schema.fromMap({'const': 'pinned'}),
        currentValue: const PresenceValue.absent(),
        admits: (value) => value is int,
        emptySeed: const PresenceValue(0),
      );
      expect(result.valueOrNull, 0);
    });

    test('a present current value wins over the schema default', () {
      final result = switchRepresentationValue(
        targetSchema: Schema.fromMap({'type': 'string', 'default': 'dflt'}),
        currentValue: const PresenceValue('kept'),
      );
      expect(result.valueOrNull, 'kept');
    });

    test('the schema default applies when no value is present', () {
      final result = switchRepresentationValue(
        targetSchema: Schema.fromMap({'type': 'string', 'default': 'dflt'}),
        currentValue: const PresenceValue.absent(),
      );
      expect(result.valueOrNull, 'dflt');
    });

    test('without pinned/value/seed/emptySeed the absent value passes through', () {
      final result = switchRepresentationValue(
        targetSchema: Schema.fromMap({'type': 'string'}),
        currentValue: const PresenceValue.absent(),
      );
      expect(result.present, isFalse);
    });
  });

  group('variant switching under value-driven rebuilds', () {
    test('applyVariantSwitched refreshes the switched-to branch, selection stays widget-owned', () async {
      final registry = buildRegistry();
      final schema = Schema.fromMap({
        'oneOf': [
          {
            'type': 'string',
            'title': 'A',
            'default': 'abc',
          },
          {'type': 'integer', 'title': 'B'},
        ],
      });

      final state = (await buildRootState(registry, schema, value: const PresenceValue.absent()))!;
      final matchedAtBuild = state.matchedVariantIndices;

      JsonFieldState? written;
      registry
          .handlerForField(state)
          .applyVariantSwitched(
            oldIndex: null,
            newIndex: 0,
            fieldState: state,
            onChanged: (s) => written = s,
          );

      expect(written, isNotNull);
      // The branch default is written to the value...
      expect(written!.valueOrNull, 'abc');
      // ...and the switched-to branch state is refreshed with it instead of
      // keeping the state built for the old (absent) value.
      expect(written!.variants![0].valueOrNull, 'abc');
      // The model selection is NOT written: the user's intent is not
      // derivable from the data, the Variant widget owns the live selection.
      expect(written!.matchedVariantIndices, matchedAtBuild);
    });

    Widget buildValueDrivenRoot(
      JsonHandlerRegistry registry,
      Schema schema,
      JsonFieldState Function() getState,
      Future<void> Function(JsonFieldState) onChanged,
    ) {
      return MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Builder(
              builder: (context) {
                final state = getState();
                return registry
                    .handlerForField(state)
                    .buildField(
                      context: context,
                      fieldState: state,
                      displayContext: FieldDisplayContext.root(formState: state),
                      onChanged: (s) => unawaited(onChanged(s)),
                    );
              },
            ),
          ),
        ),
      );
    }

    testWidgets('Location: a filled city field does not lock the switcher on Coordinates', (tester) async {
      final registry = buildRegistry();
      // The reported regression schema: the value {city: ...} uniquely
      // matches the City branch (Coordinates misses its required lat/lon
      // while the user is still filling them in), so any rule "a unique
      // match overrides the user's choice" makes Coordinates unreachable.
      final schema = Schema.fromMap({
        'title': 'Location',
        'type': 'object',
        'properties': {
          'city': {'type': 'string'},
        },
        'anyOf': [
          {
            'title': 'City',
            'properties': {
              'city': {'type': 'string'},
            },
            'required': ['city'],
          },
          {
            'title': 'Coordinates',
            'properties': {
              'lat': {'type': 'number'},
              'lon': {'type': 'number'},
            },
            'required': ['lat', 'lon'],
          },
        ],
      });

      var state = (await buildRootState(registry, schema, value: const PresenceValue(<String, Object?>{})))!;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => buildValueDrivenRoot(registry, schema, () => state, (s) async {
            // A value-driven root (the example app): only the value
            // survives, the state is rebuilt from scratch.
            final rebuilt = (await buildRootState(registry, schema, value: s.value))!;
            setState(() => state = rebuilt);
          }),
        ),
      );
      await tester.pumpAndSettle();

      // Fill city: the rebuilt value uniquely matches the City branch.
      await tester.enterText(find.byType(TextField).first, 'Amsterdam');
      await tester.pumpAndSettle();

      // Switching to Coordinates must work and stick...
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Coordinates').last);
      await tester.pumpAndSettle();
      expect(tester.widget<DropdownButton<int>>(find.byType(DropdownButton<int>)).value, 1);

      // ...including across the rebuilds caused by filling the branch in
      // (city alone still uniquely matches City until lon is entered).
      await tester.enterText(find.widgetWithText(TextField, 'lat'), '52');
      await tester.pumpAndSettle();
      expect(tester.widget<DropdownButton<int>>(find.byType(DropdownButton<int>)).value, 1);

      await tester.enterText(find.widgetWithText(TextField, 'lon'), '4');
      await tester.pumpAndSettle();

      expect(tester.widget<DropdownButton<int>>(find.byType(DropdownButton<int>)).value, 1);
      expect(state.valueOrNull, {'city': 'Amsterdam', 'lat': 52.0, 'lon': 4.0});
    });

    testWidgets('an ambiguous value keeps the user choice across rebuilds (Any of 0)', (tester) async {
      final registry = buildRegistry();
      // An empty object matches both property-only branches equally, so the
      // rebuilt matchedVariantIndices cannot re-derive the choice.
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

      var state = (await buildRootState(registry, schema, value: const PresenceValue(<String, Object?>{})))!;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => buildValueDrivenRoot(registry, schema, () => state, (s) async {
            final rebuilt = (await buildRootState(registry, schema, value: s.value))!;
            setState(() => state = rebuilt);
          }),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Option 2').last);
      await tester.pumpAndSettle();

      // The dropdown must not snap back to Option 1 after the rebuild.
      expect(tester.widget<DropdownButton<int>>(find.byType(DropdownButton<int>)).value, 1);
    });
  });

  group('union type list synthesizes variant branches', () {
    test('synthesizedTypeBranchSchemas narrows the schema to each non-null type', () {
      final schema = Schema.fromMap({
        'type': ['string', 'integer'],
        'title': 'Val',
        'default': 'abc',
        'minimum': 0,
      });

      final branches = synthesizedTypeBranchSchemas(schema)!;

      expect(branches, hasLength(2));
      expect(branches[0].type, 'string');
      expect(branches[0].title, 'string');
      expect(branches[0].value['default'], 'abc');
      expect(branches[0].value['minimum'], 0);
      expect(branches[1].type, 'integer');
      expect(branches[1].title, 'integer');
      // A default of a foreign type must not leak into the branch: switching
      // would write it into the document.
      expect(branches[1].value.containsKey('default'), isFalse);
    });

    test('duplicate types in the union (invalid per spec) do not multiply the branches', () {
      // ["string", "string", "null"] collapses to the nullable idiom: a
      // single string field, no switcher.
      expect(
        synthesizedTypeBranchSchemas(
          Schema.fromMap({
            'type': ['string', 'string', 'null'],
          }),
        ),
        isNull,
      );

      final branches = synthesizedTypeBranchSchemas(
        Schema.fromMap({
          'type': ['string', 'integer', 'string'],
        }),
      )!;
      expect(branches.map((b) => b.type), ['string', 'integer']);
    });

    test('no synthesis for the nullable idiom, an enum, or a single type', () {
      expect(
        synthesizedTypeBranchSchemas(
          Schema.fromMap({
            'type': ['string', 'null'],
          }),
        ),
        isNull,
      );
      expect(synthesizedTypeBranchSchemas(Schema.fromMap({'type': 'string'})), isNull);
      expect(
        synthesizedTypeBranchSchemas(
          Schema.fromMap({
            'type': ['string', 'integer'],
            'enum': ['a', 1],
          }),
        ),
        isNull,
      );
    });

    test('a schema with no type constraint at all synthesizes a branch per JSON type', () {
      // The empty schema admits any value: a union of every type, so the
      // Variant switcher (not the read-only unknown field) is the editor.
      final branches = synthesizedTypeBranchSchemas(Schema.fromMap({}))!;
      expect(branches.map((b) => b.type), ['string', 'integer', 'number', 'boolean', 'object', 'array']);

      // The object branch admits any properties explicitly: without it the
      // strict requireExplicitAdditionalProperties policy would render a
      // dead-end object editor (no properties, no add button).
      final objectBranch = branches.singleWhere((b) => b.type == 'object');
      expect(objectBranch.value['additionalProperties'], isTrue);

      // Annotation-only keywords do not constrain the type either.
      expect(synthesizedTypeBranchSchemas(Schema.fromMap({'title': 'Anything'})), isNotNull);
    });

    test('no all-types synthesis when the type is inferable from keywords or enum/const', () {
      // Characteristic keywords imply the type ({"properties"} -> object):
      // the inferred editor is reachable, a switcher would be noise.
      expect(synthesizedTypeBranchSchemas(Schema.fromMap({'properties': <String, Object?>{}})), isNull);
      expect(synthesizedTypeBranchSchemas(Schema.fromMap({'minLength': 2})), isNull);
      // enum/const fix the value and its type via the value picker.
      expect(
        synthesizedTypeBranchSchemas(
          Schema.fromMap({
            'enum': ['a', 'b'],
          }),
        ),
        isNull,
      );
      expect(synthesizedTypeBranchSchemas(Schema.fromMap({'const': 5})), isNull);
    });

    test('the state gets branches and the branch matching the value is selected', () async {
      final registry = buildRegistry();
      final schema = Schema.fromMap({
        'type': ['string', 'integer'],
      });

      final absentState = (await buildRootState(registry, schema, value: const PresenceValue.absent()))!;
      expect(absentState.variants, hasLength(2));

      final intState = (await buildRootState(registry, schema, value: const PresenceValue(42)))!;
      expect(intState.matchedVariantIndices, contains(1));
    });

    test('an explicit anyOf wins over the type list (no synthesized branches)', () async {
      final registry = buildRegistry();
      final schema = Schema.fromMap({
        'type': ['string', 'integer'],
        'anyOf': [
          {'type': 'string', 'maxLength': 3},
          {'type': 'integer', 'minimum': 0},
        ],
      });

      final state = (await buildRootState(registry, schema, value: const PresenceValue.absent()))!;

      expect(state.variants, hasLength(2));
      // Branches come from the anyOf as is: no synthesized type-name titles.
      expect(state.variants![0].title, isNull);
      expect(state.variants![0].schema?.value['maxLength'], 3);
    });

    testWidgets('the user can switch the branch to integer and enter a number', (tester) async {
      final registry = buildRegistry();
      final schema = Schema.fromMap({
        'type': ['string', 'integer'],
        'title': 'Value',
      });
      var state = (await buildRootState(registry, schema, value: const PresenceValue.absent()))!;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Builder(
                  builder: (context) => registry
                      .handlerForField(state)
                      .buildField(
                        context: context,
                        fieldState: state,
                        displayContext: FieldDisplayContext.root(formState: state),
                        onChanged: (s) => setState(() => state = s),
                      ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('integer').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '42');
      await tester.pumpAndSettle();

      expect(state.valueOrNull, isA<int>());
      expect(state.valueOrNull, 42);
    });

    testWidgets('an external value of another type switches the branch even after form edits', (tester) async {
      final registry = buildRegistry();
      final schema = Schema.fromMap({
        'type': ['string', 'integer'],
        'title': 'Value',
      });
      var state = (await buildRootState(registry, schema, value: const PresenceValue('abc')))!;
      late StateSetter setRootState;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            setRootState = setState;
            return MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Builder(
                    builder: (context) => registry
                        .handlerForField(state)
                        .buildField(
                          context: context,
                          fieldState: state,
                          displayContext: FieldDisplayContext.root(formState: state),
                          // A value-driven root (the example app): only the
                          // value survives, the state is rebuilt from scratch.
                          onChanged: (s) => unawaited(() async {
                            final rebuilt = (await buildRootState(registry, schema, value: s.value))!;
                            setRootState(() => state = rebuilt);
                          }()),
                        ),
                  ),
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<DropdownButton<int>>(find.byType(DropdownButton<int>)).value, 0);

      // The user edits the string in the form: the echo of this edit is not
      // an external change and must not reset the selection...
      await tester.enterText(find.byType(TextField), 'abcd');
      await tester.pumpAndSettle();
      expect(state.valueOrNull, 'abcd');
      expect(tester.widget<DropdownButton<int>>(find.byType(DropdownButton<int>)).value, 0);

      // ...but when the document is replaced from outside (the app's JSON
      // editor) with a value of another union type, the switcher must follow
      // the new value instead of staying locked by the earlier edit.
      state = (await buildRootState(registry, schema, value: const PresenceValue(42)))!;
      setRootState(() {});
      await tester.pumpAndSettle();

      expect(tester.widget<DropdownButton<int>>(find.byType(DropdownButton<int>)).value, 1);
    });
  });
}

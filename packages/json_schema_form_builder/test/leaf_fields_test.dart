import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_foundation/form_foundation.dart' show CollapsedValueField, StringDataUrlField;
import 'package:json_schema_form_builder/json_schema_form_builder.dart';

import 'helpers.dart';

void main() {
  group('inline editors collapse to a dialog button in cramped width', () {
    Widget buildConstrainedForm(JsonHandlerRegistry registry, JsonFieldState state, double width) {
      return MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: Builder(
                  builder: (context) => registry
                      .handlerForField(state)
                      .buildField(
                        context: context,
                        fieldState: state,
                        displayContext: FieldDisplayContext.root(formState: state),
                        onChanged: (_) {},
                      ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    Future<JsonFieldState> buildNestedArrayState(JsonHandlerRegistry registry) async {
      final schema = Schema.fromMap({
        'type': 'object',
        'properties': {
          'arr': {
            'type': 'array',
            'items': {'type': 'string'},
          },
        },
      });
      return (await buildRootState(
        registry,
        schema,
        value: const PresenceValue({
          'arr': ['a'],
        }),
      ))!;
    }

    Future<JsonFieldState> buildNestedObjectState(JsonHandlerRegistry registry) async {
      final schema = Schema.fromMap({
        'type': 'object',
        'properties': {
          'obj': {
            'type': 'object',
            'properties': {
              'name': {'type': 'string'},
            },
          },
        },
      });
      return (await buildRootState(
        registry,
        schema,
        value: const PresenceValue({
          'obj': {'name': 'x'},
        }),
      ))!;
    }

    testWidgets('an inline nested array stays inline when the width is comfortable', (tester) async {
      final registry = buildRegistry(inline: true);
      final state = await buildNestedArrayState(registry);

      await tester.pumpWidget(buildConstrainedForm(registry, state, 800));
      // The width is measured during layout and applied post-frame.
      await tester.pump();

      expect(find.byType(CollapsedValueField), findsNothing);
    });

    testWidgets('an inline nested array collapses to a dialog button when cramped', (tester) async {
      final registry = buildRegistry(inline: true);
      final state = await buildNestedArrayState(registry);

      await tester.pumpWidget(buildConstrainedForm(registry, state, 200));
      await tester.pump();

      expect(find.byType(CollapsedValueField), findsOneWidget);
    });

    testWidgets('an inline nested object collapses to a dialog button when cramped', (tester) async {
      final registry = buildRegistry(inline: true);
      final state = await buildNestedObjectState(registry);

      await tester.pumpWidget(buildConstrainedForm(registry, state, 200));
      await tester.pump();

      expect(find.byType(CollapsedValueField), findsOneWidget);
    });

    testWidgets('an inline nested object stays inline when the width is comfortable', (tester) async {
      final registry = buildRegistry(inline: true);
      final state = await buildNestedObjectState(registry);

      await tester.pumpWidget(buildConstrainedForm(registry, state, 800));
      await tester.pump();

      expect(find.byType(CollapsedValueField), findsNothing);
    });
  });

  group('data-url format', () {
    testWidgets('a picked file is written as a data URL', (tester) async {
      final registry = buildRegistry(
        filePicker: () async => PickedFileData(
          name: 'photo.png',
          bytes: Uint8List.fromList(const [1, 2, 3, 4]),
          mimeType: 'image/png',
        ),
      );
      final schema = Schema.fromMap({
        'type': 'string',
        'format': 'data-url',
        'title': 'Single file',
      });
      final state = (await buildRootState(registry, schema, value: const PresenceValue.absent(), title: schema.title))!;

      JsonFieldState? updated;
      await tester.pumpWidget(buildArrayForm(registry, state, (s) => updated = s));

      expect(find.byType(StringDataUrlField), findsOneWidget);

      await tester.tap(find.byIcon(Icons.attach_file));
      await tester.pump();

      expect(updated!.valueOrNull, 'data:image/png;name=photo.png;base64,${base64Encode(const [1, 2, 3, 4])}');
    });

    testWidgets('without a configured picker the field is shown with a disabled pick button', (tester) async {
      final registry = buildRegistry();
      final schema = Schema.fromMap({'type': 'string', 'format': 'data-url'});
      final state = (await buildRootState(registry, schema, value: const PresenceValue.absent()))!;

      await tester.pumpWidget(buildArrayForm(registry, state, (_) {}));

      final button = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.attach_file));
      expect(button.onPressed, isNull);
    });
  });

  group('typedValue: the single boundary conversion of leaf states', () {
    IntFieldState intState(Object? v) => IntFieldState(value: PresenceValue(v), variants: null, rootSchema: null);
    DoubleFieldState doubleState(Object? v) => DoubleFieldState(value: PresenceValue(v), variants: null, rootSchema: null);
    BoolFieldState boolState(Object? v) => BoolFieldState(value: PresenceValue(v), variants: null, rootSchema: null);
    StringFieldState stringState(PresenceValue<dynamic> v) => StringFieldState(value: v, variants: null, rootSchema: null);

    test('int: exact int64-representable doubles convert, the rest is null', () {
      expect(intState(5).typedValue, 5);
      expect(intState(5.0).typedValue, 5);
      expect(intState(5.5).typedValue, null);
      // Beyond int64: toInt() would silently saturate to 2^63-1.
      expect(intState(1e30).typedValue, null);
      expect(intState(double.infinity).typedValue, null);
      expect(intState('5').typedValue, null);
    });

    test('double: any num converts, since JSON `1` parses to a Dart int', () {
      expect(doubleState(1).typedValue, 1.0);
      expect(doubleState(1.5).typedValue, 1.5);
      expect(doubleState('1.5').typedValue, null);
    });

    test('bool: strict, a mismatched value shows the indeterminate state', () {
      expect(boolState(true).typedValue, true);
      expect(boolState('true').typedValue, null);
      expect(boolState(1).typedValue, null);
    });

    test('string: lenient toString keeps a mismatched value visible', () {
      expect(stringState(const PresenceValue('a')).typedValue, 'a');
      expect(stringState(const PresenceValue(42)).typedValue, '42');
      expect(stringState(const PresenceValue(null)).typedValue, null);
      expect(stringState(const PresenceValue.absent()).typedValue, null);
    });
  });

  group('boolean field is two-state', () {
    testWidgets('a click after true writes false, never clearing the field', (tester) async {
      final registry = buildRegistry();
      final schema = Schema.fromMap({'type': 'boolean', 'title': 'Flag'});
      final state = (await buildRootState(registry, schema, value: const PresenceValue(true)))!;

      JsonFieldState? updated;
      await tester.pumpWidget(buildArrayForm(registry, state, (s) => updated = s));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      // The old tri-state cycle wrote the empty value here (true -> null),
      // which for an additional property destroyed the field.
      expect(updated, isNotNull);
      expect(updated!.value.present, isTrue);
      expect(updated!.valueOrNull, isFalse);
    });

    testWidgets('a nullable schema keeps the third state and writes an explicit null', (tester) async {
      final registry = buildRegistry();
      final schema = Schema.fromMap({
        'type': ['boolean', 'null'],
        'title': 'Flag',
      });
      final state = (await buildRootState(registry, schema, value: const PresenceValue(true)))!;

      JsonFieldState? updated;
      await tester.pumpWidget(buildArrayForm(registry, state, (s) => updated = s));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      expect(updated, isNotNull);
      expect(updated!.value.present, isTrue);
      expect(updated!.valueOrNull, isNull);
    });
  });
}

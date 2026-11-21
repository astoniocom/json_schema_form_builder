// EnumField: the dropdown editor of select-like fields. The state's
// enumValues are offered together with a "Not selected" entry (clearing to
// absent), the shown label follows external value changes, and readOnly
// disables the control.
import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema_form_builder/json_schema_form_builder.dart';
// The widget itself is internal (the facade exports the handler and the
// state); tests may reach into src.
import 'package:json_schema_form_builder/src/handlers/enum/enum_field.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  EnumFieldState state({
    PresenceValue<dynamic> value = const PresenceValue.absent(),
    List<Object?> enumValues = const ['red', 'green', 'blue'],
    FieldAnnotations? annotations,
  }) => EnumFieldState(
    value: value,
    variants: null,
    rootSchema: null,
    enumValues: enumValues,
    title: 'Color',
    fieldAnnotations: annotations,
  );

  Widget harness(EnumFieldState fieldState, {void Function(JsonFieldState)? onChanged}) => MaterialApp(
    localizationsDelegates: JsonFormLocalizations.localizationsDelegates,
    supportedLocales: JsonFormLocalizations.supportedLocales,
    home: Scaffold(
      body: EnumField(
        fieldState: fieldState,
        displayContext: FieldDisplayContext.root(formState: fieldState),
        onChanged: onChanged,
      ),
    ),
  );

  final arrow = find.byIcon(Icons.arrow_drop_down);

  testWidgets('shows the current value and offers every option plus Not selected', (tester) async {
    await tester.pumpWidget(harness(state(value: const PresenceValue('green')), onChanged: (_) {}));
    await tester.pumpAndSettle();

    // The field shows the selected value's label.
    expect(find.text('green'), findsOneWidget);

    await tester.tap(arrow);
    await tester.pumpAndSettle();

    expect(find.text('Not selected'), findsOneWidget);
    expect(find.text('red'), findsOneWidget);
    expect(find.text('blue'), findsOneWidget);
    // The selected value: once in the field, once in the open menu.
    expect(find.text('green'), findsNWidgets(2));
  });

  testWidgets('selecting an option reports the new value', (tester) async {
    JsonFieldState? changed;
    await tester.pumpWidget(harness(state(value: const PresenceValue('red')), onChanged: (s) => changed = s));
    await tester.pumpAndSettle();

    await tester.tap(arrow);
    await tester.pumpAndSettle();
    await tester.tap(find.text('blue'));
    await tester.pumpAndSettle();

    expect(changed, isNotNull);
    expect(changed!.value.valueOrNull, 'blue');
  });

  testWidgets('Not selected clears the value to absent', (tester) async {
    JsonFieldState? changed;
    await tester.pumpWidget(harness(state(value: const PresenceValue('red')), onChanged: (s) => changed = s));
    await tester.pumpAndSettle();

    await tester.tap(arrow);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not selected'));
    await tester.pumpAndSettle();

    expect(changed, isNotNull);
    expect(changed!.value.present, isFalse);
  });

  testWidgets('an external value change resyncs the shown label', (tester) async {
    await tester.pumpWidget(harness(state(value: const PresenceValue('red')), onChanged: (_) {}));
    await tester.pumpAndSettle();
    expect(find.text('red'), findsOneWidget);

    await tester.pumpWidget(harness(state(value: const PresenceValue('blue')), onChanged: (_) {}));
    await tester.pumpAndSettle();

    expect(find.text('blue'), findsOneWidget);
    expect(find.text('red'), findsNothing);
  });

  testWidgets('a null enum value is shown with the localized label', (tester) async {
    await tester.pumpWidget(
      harness(
        state(value: const PresenceValue(null), enumValues: const [null, 'x']),
        onChanged: (_) {},
      ),
    );
    await tester.pumpAndSettle();

    // The field shows the null option's label...
    expect(find.text('No value'), findsOneWidget);

    await tester.tap(arrow);
    await tester.pumpAndSettle();

    // ...and the menu distinguishes it from the clearing entry.
    expect(find.text('No value'), findsNWidgets(2));
    expect(find.text('Not selected'), findsOneWidget);
    expect(find.text('x'), findsOneWidget);
  });

  testWidgets('readOnly (and null onChanged) render the dropdown disabled', (tester) async {
    await tester.pumpWidget(
      harness(state(value: const PresenceValue('red'), annotations: FieldAnnotations(readOnly: true)), onChanged: (_) {}),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<IconButton>(find.byType(IconButton)).onPressed, isNull);
    await tester.tap(arrow, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Not selected'), findsNothing, reason: 'a readOnly dropdown must not open');

    // The same via a null onChanged.
    await tester.pumpWidget(harness(state(value: const PresenceValue('red'))));
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(find.byType(IconButton)).onPressed, isNull);
  });
}

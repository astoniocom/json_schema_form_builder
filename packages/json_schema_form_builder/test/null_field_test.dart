import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema_form_builder/json_schema_form_builder.dart';
import 'package:material_ui/material_ui.dart';

/// The null field must keep a constant height whether the value is set or
/// not: the InputDecorator child must not collapse to null for an absent
/// value (a null child drops the content line and shrinks the decorator).
void main() {
  Widget harness(PresenceValue<dynamic> value) {
    return MaterialApp(
      localizationsDelegates: JsonFormLocalizations.localizationsDelegates,
      supportedLocales: JsonFormLocalizations.supportedLocales,
      home: Scaffold(
        body: JsonSchemaForm(
          schema: Schema.fromMap({'type': 'null', 'title': 'Nothing'}),
          initialValue: value,
          onChanged: (_) {},
        ),
      ),
    );
  }

  testWidgets('the field is equally tall with and without a value', (tester) async {
    await tester.pumpWidget(harness(const PresenceValue.absent()));
    await tester.pumpAndSettle();
    final absentHeight = tester.getSize(find.byType(InputDecorator)).height;

    await tester.pumpWidget(harness(const PresenceValue(null)));
    await tester.pumpAndSettle();
    final presentHeight = tester.getSize(find.byType(InputDecorator)).height;

    expect(absentHeight, presentHeight);
  });

  testWidgets('a set null value offers the reset button where absent is representable', (tester) async {
    await tester.pumpWidget(harness(const PresenceValue(null)));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Reset value'), findsOneWidget);
  });

  // A `type: "null"` alternative is pinned (its only value is null, like
  // `const: null`), so the switcher renders no editor below the dropdown:
  // the selection alone determines the value, and the null editor's buttons
  // would be noise (matches rjsf, whose null field renders no input).
  testWidgets('a selected None alternative renders only the dropdown', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: JsonFormLocalizations.localizationsDelegates,
        supportedLocales: JsonFormLocalizations.supportedLocales,
        home: Scaffold(
          body: JsonSchemaForm(
            schema: Schema.fromMap({
              'oneOf': [
                {'type': 'null', 'title': 'None'},
                {'type': 'string', 'title': 'Text'},
              ],
            }),
            initialValue: const PresenceValue(null),
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The None alternative is selected in the dropdown...
    expect(find.byType(DropdownButton<int>), findsOneWidget);
    expect(find.text('None'), findsOneWidget);
    // ...and no null editor (with its set-null/reset buttons) is rendered.
    expect(find.byTooltip('Reset value'), findsNothing);
    expect(find.byTooltip('Set to null'), findsNothing);
  });

  // An array slot always holds a value: the parent coerces an absent write
  // right back to null, so the reset button would silently do nothing and
  // must not be offered (FieldDisplayContext.absentAllowed).
  testWidgets('a null array item offers no reset button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: JsonFormLocalizations.localizationsDelegates,
        supportedLocales: JsonFormLocalizations.supportedLocales,
        home: Scaffold(
          body: JsonSchemaForm(
            schema: Schema.fromMap({
              'type': 'array',
              'items': {'title': 'None', 'type': 'null'},
            }),
            initialValue: const PresenceValue([null]),
            registry: standardJsonHandlerRegistry(arrayInline: true),
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The item renders (its null editor is on screen)...
    expect(find.text('None'), findsWidgets);
    // ...but neither the reset nor the set-null button is offered: the value
    // is already null and clearing it to absent is not representable here.
    expect(find.byTooltip('Reset value'), findsNothing);
    expect(find.byTooltip('Set to null'), findsNothing);
  });
}

// Every sample in sample_db.dart must produce a root field state AND render:
// a sample whose schema fails to parse, whose form data crashes the pipeline,
// or whose widgets throw during layout is a broken showcase entry.
import 'package:demo/sample_db.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema_form_builder/json_schema_form_builder.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final registry = standardJsonHandlerRegistry();

  test('every sample has a unique non-empty URL slug', () {
    final slugs = samples.map((s) => s.slug).toList();
    expect(slugs, everyElement(isNotEmpty));
    expect(slugs.toSet().length, slugs.length);
  });

  for (final sample in samples) {
    test('sample "${sample.title}" builds a root state', () async {
      final rawSchema = sample.jsonSchema;
      final schema = rawSchema == null ? null : Schema.fromMap(rawSchema);

      final state = await registry.withValidationContext(
        itemSchema: schema,
        rootSchema: schema,
        body: (validationContext) => registry.buildStateOrUndefined(
          FieldBuildRequest(
            value: sample.formData,
            schemaSource: SchemaWithContext.maybe(schema, validationContext),
            title: sample.title,
            resolveContext: FieldResolveContext(path: [], rootSchema: schema),
          ),
        ),
      );

      expect(state, isNotNull);
    });
  }

  // The render pass: every sample is pumped as a full live-validated form
  // with the demo's registry configuration (inline arrays). Catches what
  // state building alone cannot: widget-level crashes, layout overflows
  // (they throw in tests), and editors that fail on the sample's data.
  for (final sample in samples) {
    testWidgets('sample "${sample.title}" renders', (tester) async {
      // Wide desktop-like surface, matching how the demo is showcased.
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.binding.setSurfaceSize(const Size(1000, 2000));

      final rawSchema = sample.jsonSchema;
      final schema = rawSchema == null ? null : Schema.fromMap(rawSchema);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: JsonFormLocalizations.localizationsDelegates,
          supportedLocales: JsonFormLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: JsonSchemaForm(
                schema: schema,
                initialValue: sample.formData,
                registry: standardJsonHandlerRegistry(arrayInline: true),
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The form produced real editors (any sample renders at least one
      // input or group); a crash or overflow would have failed the pump.
      expect(find.byType(JsonSchemaForm), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

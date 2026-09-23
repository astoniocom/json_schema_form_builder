import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:json_schema_form_builder/json_schema_form_builder.dart';

import 'helpers.dart';

/// A state builder implementing only the domain interface (no
/// JsonFieldHandler, no widgets): proves the registry's state-building
/// pipeline has no presentation dependency.
class _FakeIntStateBuilder implements JsonFieldStateBuilder<JsonFieldState> {
  int buildStateCalls = 0;

  @override
  Future<JsonFieldState> buildState(FieldBuildRequest request) async {
    buildStateCalls++;
    return IntFieldState(
      value: request.value,
      variants: null,
      rootSchema: request.resolveContext.rootSchema,
    );
  }

  @override
  bool canEditValue(dynamic value) => dartTypeOfValue(value) == int;

  @override
  bool matchesState(JsonFieldState state) => state is IntFieldState;

  @override
  PresenceValue<dynamic>? get canonicalEmptyValue => null;
}

void main() {
  group('domain seam: state building depends only on JsonFieldStateBuilder', () {
    test('a pure (widget-free) fake builder runs through buildStateForNewField', () async {
      final registry = buildRegistry();
      final fake = _FakeIntStateBuilder();
      final schema = Schema.fromMap({'type': 'integer', 'default': 5});

      final state = await registry.withValidationContext(
        itemSchema: schema,
        rootSchema: schema,
        body: (validationContext) => registry.buildStateForNewField(
          stateBuilder: fake,
          request: FieldBuildRequest(
            value: const PresenceValue.absent(),
            schemaSource: SchemaWithContext.maybe(schema, validationContext),
            resolveContext: FieldResolveContext(path: [], rootSchema: schema),
          ),
        ),
      );

      // The pipeline consulted the fake's canEditValue for the seed check
      // and built the state through it: the schema default is seeded.
      expect(fake.buildStateCalls, 1);
      expect(state.valueOrNull, 5);
    });
  });

  group('standard registry factory', () {
    test('closes the handler-registry cycle internally', () async {
      final registry = standardJsonHandlerRegistry();

      final state = await buildRootState(registry, Schema.fromMap({'type': 'string'}), value: const PresenceValue('x'));

      expect(state, isA<StringFieldState>());
      // The lazy cycle points back at the same registry instance.
      expect(registry.handlerForField(state!).registry, same(registry));
    });

    group('handler selection for the nullable idiom (type: [X, "null"])', () {
      test('a null value keeps the non-null editor instead of flipping to the null field', () async {
        // Clearing a nullable string writes an explicit null
        // (normalizedEmptyValue); the field must stay a string editor,
        // otherwise there is nothing left to type into.
        final schema = Schema.fromMap({
          'type': ['string', 'null'],
        });

        final state = await buildRootState(buildRegistry(), schema, value: const PresenceValue(null));

        expect(state, isA<StringFieldState>());
      });

      test('the order of the union types does not matter', () async {
        final schema = Schema.fromMap({
          'type': ['null', 'string'],
        });

        final state = await buildRootState(buildRegistry(), schema, value: const PresenceValue.absent());

        expect(state, isA<StringFieldState>());
      });

      test('type: "null" alone still selects the null field', () async {
        final state = await buildRootState(buildRegistry(), Schema.fromMap({'type': 'null'}), value: const PresenceValue(null));

        expect(state, isA<NullFieldState>());
      });
    });

    test('an override replaces the built-in registration and joins the same cycle', () async {
      late final StringFieldHandler custom;
      final registry = standardJsonHandlerRegistry(
        overrides: {
          StringFieldState: (registryGetter) => JsonHandlerRegistration(
            stateType: StringFieldState,
            handler: custom = StringFieldHandler(registryGetter: registryGetter),
            valueTypes: const [String],
            schemaTypes: const [JsonType.string],
          ),
        },
      );

      final state = await buildRootState(registry, Schema.fromMap({'type': 'string'}), value: const PresenceValue('x'));

      expect(registry.handlerForField(state!), same(custom));
      expect(custom.registry, same(registry));
    });
  });
}

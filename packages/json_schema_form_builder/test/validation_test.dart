import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema_form_builder/json_schema_form_builder.dart';

import 'helpers.dart';

/// Runs [body] with HTTP disabled (any client creation throws), simulating
/// the offline/web environment where fetching a meta schema or a remote
/// `$ref` fails. Plain `test()` bodies otherwise have real network access
/// (the flutter_test HTTP block is installed by the widget-test binding).
Future<T> withoutNetwork<T>(Future<T> Function() body) {
  return HttpOverrides.runZoned(
    body,
    createHttpClient: (_) => throw const SocketException('Network disabled in this test'),
  );
}

void main() {
  group(r'$schema meta-schema handling', () {
    test(r'a document with $schema validates without fetching the meta schema', () async {
      final registry = buildRegistry();
      final schema = Schema.fromMap({
        r'$id': 'https://example.com/entry-schema',
        r'$schema': 'https://json-schema.org/draft/2020-12/schema',
        'description': 'JSON Schema for an fstab entry',
        'type': 'object',
        'required': ['storage'],
        'properties': {
          'storage': {
            'type': 'object',
            'oneOf': [
              {r'$ref': r'#/$defs/diskDevice'},
              {r'$ref': r'#/$defs/diskUUID'},
            ],
          },
        },
        r'$defs': {
          'diskDevice': {
            'properties': {
              'device': {'type': 'string'},
            },
            'required': ['device'],
          },
          'diskUUID': {
            'properties': {
              'label': {'type': 'string'},
            },
            'required': ['label'],
          },
        },
      });

      final errors = await registry.validateValue(
        itemSchema: schema,
        rootSchema: schema,
        value: {
          'storage': {'device': '/dev/sda1'},
        },
      );

      // The meta schema named by $schema must resolve from the local
      // registry: fetching it over the network fails offline and on the web
      // (CORS), poisoning the result with a refResolutionError.
      expect(
        errors.where((e) => (e.details ?? '').contains('meta schema')),
        isEmpty,
      );
      expect(errors, isEmpty);
    });

    test(r'a bundled schema resolves relative $refs against the root $id', () async {
      final registry = buildRegistry();
      // A bundle (rjsf example): mixins are embedded under $defs with their
      // own absolute $ids, and referenced with URIs relative to the root $id.
      final schema = Schema.fromMap({
        r'$id': 'https://jsonschema.dev/schemas/examples/non-negative-integer-bundle',
        r'$schema': 'https://json-schema.org/draft/2020-12/schema',
        'description': 'Must be a non-negative integer',
        r'$defs': {
          'https://jsonschema.dev/schemas/mixins/integer': {
            r'$id': 'https://jsonschema.dev/schemas/mixins/integer',
            'type': 'integer',
          },
          'https://jsonschema.dev/schemas/mixins/non-negative': {
            r'$id': 'https://jsonschema.dev/schemas/mixins/non-negative',
            'minimum': 0,
          },
          'nonNegativeInteger': {
            'allOf': [
              {r'$ref': '/schemas/mixins/integer'},
              {r'$ref': '/schemas/mixins/non-negative'},
            ],
          },
        },
        'properties': {
          'num': {r'$ref': r'#/$defs/nonNegativeInteger'},
        },
      });

      final state = await buildRootState(
        registry,
        schema,
        value: const PresenceValue({'num': 3}),
      );

      final objectState = state! as ObjectFieldState;
      final numState = objectState.children['num']!.state;
      // Before the fix the refs missed the registry (base URI ignored the
      // root $id) and the field degraded to UnknownFieldState.
      expect(numState, isA<IntFieldState>());
    });

    test(r'validateDataBySchema resolves $schema and bundled refs without the network', () async {
      // The root-level validation path (JsonSchemaForm, the demo) goes
      // through the standalone validateDataBySchema, which used to call the
      // plain schema.validate: a fresh context without the meta-schema
      // stubs, so a document with $schema failed immediately with "Failed
      // to resolve meta schema: https://json-schema.org/..." at #root.
      final schema = Schema.fromMap({
        r'$id': 'https://jsonschema.dev/schemas/examples/non-negative-integer-bundle',
        r'$schema': 'https://json-schema.org/draft/2020-12/schema',
        'description': 'Must be a non-negative integer',
        r'$defs': {
          'https://jsonschema.dev/schemas/mixins/integer': {
            r'$schema': 'https://json-schema.org/draft/2020-12/schema',
            r'$id': 'https://jsonschema.dev/schemas/mixins/integer',
            'type': 'integer',
          },
          'https://jsonschema.dev/schemas/mixins/non-negative': {
            r'$schema': 'https://json-schema.org/draft/2020-12/schema',
            r'$id': 'https://jsonschema.dev/schemas/mixins/non-negative',
            'minimum': 0,
          },
          'nonNegativeInteger': {
            'allOf': [
              {r'$ref': '/schemas/mixins/integer'},
              {r'$ref': '/schemas/mixins/non-negative'},
            ],
          },
        },
        'properties': {
          'num': {r'$ref': r'#/$defs/nonNegativeInteger'},
        },
      });

      await withoutNetwork(() async {
        // The demo opens the sample with an empty object: it must be clean —
        // in particular free of the meta-schema refResolutionError.
        final cleanErrors = await validateDataBySchema(schema, <String, Object?>{});
        expect(cleanErrors, isEmpty);

        // The bundled refs really constrain the value...
        final negativeErrors = await validateDataBySchema(schema, {'num': -5});
        expect(negativeErrors, isNotEmpty);
        // ... and the reported errors are about the value, not resolution.
        expect(
          negativeErrors!.where((e) => (e.details ?? '').contains('meta schema')),
          isEmpty,
        );

        expect(await validateDataBySchema(schema, {'num': 5}), isEmpty);
      });
    });
  });

  group('literal-built values (loose Dart types)', () {
    // An untyped Dart literal is Map<dynamic, dynamic>, while the validator
    // casts the data it walks to Map<String, Object?>. Every validation entry
    // point must normalize (normalizeJsonValue) instead of surfacing a bogus
    // "validator rejected the schema" error.
    final schema = Schema.fromMap({
      'type': 'object',
      'properties': {
        'name': {'type': 'string'},
        'tags': {
          'type': 'array',
          'items': {'type': 'string'},
        },
      },
      'required': ['name'],
    });

    test('an untyped empty map literal validates as data, not as a rejected schema', () async {
      final errors = await validateDataBySchema(schema, <dynamic, dynamic>{});

      expect(errors, isNotNull);
      expect(errors!.any((e) => e.isValidatorRejectedSchema), isFalse);
      // The real verdict is reported: required "name" is missing.
      expect(errors, isNotEmpty);
    });

    test('nested loose maps and lists validate through registry.validateValue', () async {
      final registry = buildRegistry();
      final errors = await registry.validateValue(
        itemSchema: schema,
        rootSchema: schema,
        value: <dynamic, dynamic>{
          'name': 'Ada',
          'tags': <dynamic>['a', 'b'],
        },
      );

      expect(errors.any((e) => e.isValidatorRejectedSchema), isFalse);
      expect(errors, isEmpty);
    });
  });

  group('validation contract: errors null = not run, empty = validated clean', () {
    test('applyErrors keeps an empty result as an empty list', () async {
      final registry = buildRegistry();
      final schema = Schema.fromMap({'type': 'string'});
      final state = (await buildRootState(registry, schema, value: const PresenceValue('x')))!;

      // Built without validation: not validated, hence not valid either.
      expect(state.isValidated, isFalse);
      expect(state.isValid, isFalse);

      final validated = state.applyErrors(const []);

      expect(validated.isValidated, isTrue);
      expect(validated.isValid, isTrue);
      expect(validated.errors, isEmpty);
      expect(validated.hasErrors, isFalse);
    });

    test('a failed validation is distinct from both', () async {
      final registry = buildRegistry();
      final schema = Schema.fromMap({'type': 'string'});
      final state = (await buildRootState(registry, schema, value: const PresenceValue('x')))!;

      final failed = state.applyErrors([ValidationError(ValidationErrorType.custom, path: const [], details: 'boom')]);

      expect(failed.isValidated, isTrue);
      expect(failed.isValid, isFalse);
      expect(failed.hasErrors, isTrue);
    });

    test('markUnvalidated resets a validated state back to "not run"', () async {
      final registry = buildRegistry();
      final schema = Schema.fromMap({'type': 'string'});
      final state = (await buildRootState(registry, schema, value: const PresenceValue('x')))!;

      // Not validated yet: markUnvalidated is an identity.
      expect(identical(state.markUnvalidated(), state), isTrue);

      final failed = state.applyErrors([ValidationError(ValidationErrorType.custom, path: const [], details: 'boom')]);
      final reset = failed.markUnvalidated();

      expect(reset.isValidated, isFalse);
      expect(reset.errors, isNull);
      // The rest of the state survives the reset.
      expect(reset.value.valueOrNull, 'x');
    });

    test('a clean validation marks object children validated too', () async {
      final registry = buildRegistry();
      final schema = Schema.fromMap({
        'type': 'object',
        'properties': {
          'name': {'type': 'string'},
        },
      });
      final state = (await buildRootState(registry, schema, value: const PresenceValue({'name': 'x'})))! as ObjectFieldState;

      final validated = state.applyErrors(const []);

      expect(validated.isValid, isTrue);
      expect(validated.children['name']!.state.isValid, isTrue);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema_form_builder/json_schema_form_builder.dart';
// The normalizer is a validation-internal detail, not part of the facade.
import 'package:json_schema_form_builder/src/utils/utils.dart';

import 'helpers.dart';

/// Draft-07 tuple syntax (`items: [...]` + `additionalItems`) renders
/// natively, but the bundled validator speaks 2020-12 only. Every validator
/// entry point rewrites the schema via normalizeDraft07Tuples first, so both
/// dialects validate instead of surfacing "validator rejected schema".
void main() {
  group('normalizeDraft07Tuples: the rewrite', () {
    test('a list-valued items becomes prefixItems, additionalItems becomes items', () {
      final schema = Schema.fromMap({
        'type': 'array',
        'items': [
          {'type': 'string'},
          {'type': 'boolean'},
        ],
        'additionalItems': {'type': 'number'},
      });

      final normalized = normalizeDraft07Tuples(schema).value;

      expect(normalized['prefixItems'], [
        {'type': 'string'},
        {'type': 'boolean'},
      ]);
      expect(normalized['items'], {'type': 'number'});
      expect(normalized.containsKey('additionalItems'), isFalse);
    });

    test('without additionalItems the moved items key is removed', () {
      final schema = Schema.fromMap({
        'type': 'array',
        'items': [
          {'type': 'string'},
        ],
      });

      final normalized = normalizeDraft07Tuples(schema).value;

      expect(normalized['prefixItems'], hasLength(1));
      expect(normalized.containsKey('items'), isFalse);
    });

    test('additionalItems: false survives as items: false (no extra elements)', () {
      final schema = Schema.fromMap({
        'type': 'array',
        'items': [
          {'type': 'string'},
        ],
        'additionalItems': false,
      });

      final normalized = normalizeDraft07Tuples(schema).value;

      expect(normalized['items'], isFalse);
    });

    test('nested occurrences are rewritten: properties, definitions, allOf, inner tuples', () {
      final schema = Schema.fromMap({
        'type': 'object',
        'definitions': {
          'pair': {
            'type': 'array',
            'items': [
              {'type': 'number'},
              {'type': 'number'},
            ],
          },
        },
        'properties': {
          'point': {r'$ref': '#/definitions/pair'},
          'matrix': {
            'type': 'array',
            // A homogeneous outer array whose ITEM is a tuple.
            'items': {
              'type': 'array',
              'items': [
                {'type': 'integer'},
              ],
            },
          },
        },
        'allOf': [
          {
            'properties': {
              'row': {
                'type': 'array',
                'items': [
                  {'type': 'string'},
                ],
              },
            },
          },
        ],
      });

      final normalized = normalizeDraft07Tuples(schema).value;

      final definitions = normalized['definitions']! as Map;
      expect((definitions['pair'] as Map)['prefixItems'], hasLength(2));

      final properties = normalized['properties']! as Map;
      final innerArray = (properties['matrix'] as Map)['items']! as Map;
      expect(innerArray['prefixItems'], hasLength(1));

      final allOfProperties = ((normalized['allOf']! as List).first as Map)['properties']! as Map;
      expect((allOfProperties['row'] as Map)['prefixItems'], hasLength(1));
    });

    test('a property literally named "items" is a schema position and is rewritten', () {
      final schema = Schema.fromMap({
        'type': 'object',
        'properties': {
          'items': {
            'type': 'array',
            'items': [
              {'type': 'string'},
            ],
          },
        },
      });

      final normalized = normalizeDraft07Tuples(schema).value;

      final itemsProperty = (normalized['properties']! as Map)['items']! as Map;
      expect(itemsProperty['prefixItems'], hasLength(1));
      expect(itemsProperty.containsKey('items'), isFalse);
    });

    test('const/enum/default values are data, not schemas: left untouched', () {
      final schema = Schema.fromMap({
        'type': 'object',
        'properties': {
          'config': {
            'const': {
              'items': [1, 2, 3],
            },
          },
          'choice': {
            'enum': [
              {
                'items': ['a'],
              },
            ],
          },
          'preset': {
            'type': 'object',
            'default': {
              'items': <Object?>[],
            },
          },
        },
      });

      final normalized = normalizeDraft07Tuples(schema).value;

      final properties = normalized['properties']! as Map;
      expect((properties['config'] as Map)['const'], {
        'items': [1, 2, 3],
      });
      expect(((properties['choice'] as Map)['enum'] as List).first, {
        'items': ['a'],
      });
      expect((properties['preset'] as Map)['default'], {'items': <Object?>[]});
    });

    test('a 2020-12 document passes through as the same instance', () {
      final schema = Schema.fromMap({
        'type': 'array',
        'prefixItems': [
          {'type': 'string'},
        ],
        'items': {'type': 'number'},
      });

      expect(identical(normalizeDraft07Tuples(schema), schema), isTrue);
    });
  });

  group('draft-07 tuples validate (no "validator rejected schema")', () {
    final tupleSchema = Schema.fromMap({
      'type': 'array',
      'items': [
        {'type': 'string'},
        {'type': 'boolean'},
      ],
      'additionalItems': {'type': 'number'},
    });

    test('matching tuple data validates clean', () async {
      final errors = await validateDataBySchema(tupleSchema, ['lorem', true, 5]);

      expect(errors, isEmpty);
    });

    test('a position type mismatch is a real validation error', () async {
      final errors = await validateDataBySchema(tupleSchema, [5, 'lorem']);

      expect(errors, isNotEmpty);
      expect(errors!.map((e) => e.error).join(), isNot(contains('validator')));
    });

    test('additionalItems: false rejects elements beyond the tuple', () async {
      final closed = Schema.fromMap({
        'type': 'array',
        'items': [
          {'type': 'string'},
        ],
        'additionalItems': false,
      });

      expect(await validateDataBySchema(closed, ['only']), isEmpty);
      expect(await validateDataBySchema(closed, ['only', 'extra']), isNotEmpty);
    });

    test(r'a tuple behind a $ref in definitions validates through registry.validateValue', () async {
      final registry = buildRegistry();
      final root = Schema.fromMap({
        'definitions': {
          'pair': {
            'type': 'array',
            'items': [
              {'type': 'number'},
              {'type': 'number'},
            ],
            'additionalItems': false,
          },
        },
        'type': 'object',
        'properties': {
          'point': {r'$ref': '#/definitions/pair'},
        },
      });

      final cleanErrors = await registry.validateValue(
        itemSchema: root,
        rootSchema: root,
        value: {
          'point': [1, 2],
        },
      );
      expect(cleanErrors, isEmpty);

      final dirtyErrors = await registry.validateValue(
        itemSchema: root,
        rootSchema: root,
        value: {
          'point': [1, 2, 3],
        },
      );
      expect(dirtyErrors, isNotEmpty);
    });
  });
}

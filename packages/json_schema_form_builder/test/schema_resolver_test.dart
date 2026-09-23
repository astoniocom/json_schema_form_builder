import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema_form_builder/json_schema_form_builder.dart';
import 'package:json_schema_form_builder/src/schema_resolver/schema_resolver.dart';

import 'helpers.dart';

void main() {
  group('schema resolution boundary: the subset resolved by the package', () {
    // Executable form of the contract documented at the top of
    // schema_resolver.dart: what the package flattens itself (the library
    // validates but exposes no effective-schema API) and where the known
    // holes are.
    Future<Schema> resolve(Map<String, Object?> rawSchema, Object? data) async {
      final schema = Schema.fromMap(rawSchema);
      return buildRegistry().withValidationContext(
        itemSchema: schema,
        rootSchema: schema,
        body: (context) async {
          final (resolved, _) = await resolveSchema(schema, data, const [], context!, SchemaMerger.withDefaults());
          return resolved;
        },
      );
    }

    Map<String, Object?> propertiesOf(Schema schema) => (schema.value['properties'] as Map?)?.cast<String, Object?>() ?? const {};

    test(r'$ref: target merged in, local siblings win, $ref stripped', () async {
      final resolved = await resolve({
        'definitions': {
          'name': {'type': 'string', 'title': 'From ref', 'minLength': 1},
        },
        r'$ref': '#/definitions/name',
        'title': 'Local',
      }, null);

      expect(resolved.value['type'], 'string');
      expect(resolved.value['minLength'], 1);
      expect(resolved.value['title'], 'Local');
      expect(resolved.value.containsKey(r'$ref'), isFalse);
    });

    test(r'$ref chain is expanded to the end', () async {
      final resolved = await resolve({
        'definitions': {
          'a': {r'$ref': '#/definitions/b'},
          'b': {'type': 'integer'},
        },
        r'$ref': '#/definitions/a',
      }, null);

      expect(resolved.value['type'], 'integer');
    });

    test('allOf: branches flatten (properties merged, required united)', () async {
      final resolved = await resolve({
        'type': 'object',
        'allOf': [
          {
            'properties': {
              'a': {'type': 'string'},
            },
            'required': ['a'],
          },
          {
            'properties': {
              'b': {'type': 'integer'},
            },
            'required': ['b'],
          },
        ],
      }, null);

      expect(propertiesOf(resolved).keys, containsAll(['a', 'b']));
      expect(resolved.value['required'], containsAll(['a', 'b']));
      expect(resolved.value.containsKey('allOf'), isFalse);
    });

    test('allOf branches with their own ifs are evaluated independently (per spec)', () async {
      final schema = {
        'type': 'object',
        'properties': {
          'country': {'type': 'string'},
          'currency': {'type': 'string'},
        },
        'allOf': [
          {
            'if': {
              'properties': {
                'country': {'const': 'NL'},
              },
            },
            'then': {
              'required': ['postal'],
            },
          },
          {
            'if': {
              'properties': {
                'currency': {'const': 'EUR'},
              },
            },
            'then': {
              'required': ['iban'],
            },
          },
        ],
      };

      final bothFire = await resolve(schema, {'country': 'NL', 'currency': 'EUR'});
      expect(bothFire.value['required'], containsAll(['postal', 'iban']));

      final firstOnly = await resolve(schema, {'country': 'NL', 'currency': 'USD'});
      expect(firstOnly.value['required'], contains('postal'));
      expect(firstOnly.value['required'], isNot(contains('iban')));
    });

    test('if/then/else: the matching branch merged, conditional keys stripped', () async {
      final schema = {
        'type': 'object',
        'properties': {
          'country': {'type': 'string'},
        },
        'if': {
          'properties': {
            'country': {'const': 'NL'},
          },
        },
        'then': {
          'properties': {
            'postal': {'type': 'string'},
          },
          'required': ['postal'],
        },
        'else': {
          'properties': {
            'state': {'type': 'string'},
          },
        },
      };

      final thenBranch = await resolve(schema, {'country': 'NL'});
      expect(propertiesOf(thenBranch).containsKey('postal'), isTrue);
      expect(thenBranch.value['required'], contains('postal'));
      expect(thenBranch.value.containsKey('if'), isFalse);
      expect(thenBranch.value.containsKey('then'), isFalse);
      expect(thenBranch.value.containsKey('else'), isFalse);

      final elseBranch = await resolve(schema, {'country': 'US'});
      expect(propertiesOf(elseBranch).containsKey('state'), isTrue);
      expect(propertiesOf(elseBranch).containsKey('postal'), isFalse);
    });

    test('if with none of its properties in the data does not fire (rjsf deviation from spec)', () async {
      // Per spec an empty object satisfies a requirement-free `if`, pulling
      // `then` in; rjsf (and this package) treat an untouched form as
      // "condition not fired" so conditional fields do not appear before the
      // user chose anything.
      final resolved = await resolve({
        'type': 'object',
        'properties': {
          'country': {'type': 'string'},
        },
        'if': {
          'properties': {
            'country': {'const': 'NL'},
          },
        },
        'then': {
          'properties': {
            'postal': {'type': 'string'},
          },
        },
        'else': {
          'properties': {
            'state': {'type': 'string'},
          },
        },
      }, <String, Object?>{});

      final properties = propertiesOf(resolved);
      expect(properties.containsKey('postal'), isFalse);
      expect(properties.containsKey('state'), isFalse);
    });

    test('draft-07 dependencies normalize and apply only for present keys', () async {
      // Round-tripped through JSON on purpose: decoded schemas carry
      // List<dynamic>/Map<String, dynamic> where Dart literals would infer
      // List<String>, and the resolver must survive the decoded shape (a
      // `as List<String>` cast in _resolveDependentRequired crashed exactly
      // here once the dependency key got a value).
      final schema = (jsonDecode(jsonEncode({
        'type': 'object',
        'properties': {
          'credit_card': {'type': 'string'},
          'billing_address': {'type': 'string'},
        },
        'dependencies': {
          'credit_card': ['billing_address'],
        },
      })) as Map<String, dynamic>).cast<String, Object?>();

      final active = await resolve(schema, {'credit_card': 'x'});
      expect(active.value['required'], contains('billing_address'));
      expect(active.value.containsKey('dependencies'), isFalse);

      final untouched = await resolve(schema, <String, Object?>{});
      expect(untouched.value['required'] ?? const [], isNot(contains('billing_address')));
    });

    test('dependentSchemas apply only for keys present in the data', () async {
      final schema = {
        'type': 'object',
        'properties': {
          'plan': {'type': 'string'},
        },
        'dependentSchemas': {
          'plan': {
            'properties': {
              'seats': {'type': 'integer'},
            },
          },
        },
      };

      final active = await resolve(schema, {'plan': 'pro'});
      expect(propertiesOf(active).containsKey('seats'), isTrue);
      expect(active.value.containsKey('dependentSchemas'), isFalse);

      final inactive = await resolve(schema, <String, Object?>{});
      expect(propertiesOf(inactive).containsKey('seats'), isFalse);
    });

    test(r'KNOWN LIMITATION: schemaSeedValue does not follow non-local $refs', () async {
      // Documented in schema_resolver.dart and schema_values.dart. If this
      // starts failing, the limitation was fixed: update both docs and this
      // test.
      final schema = Schema.fromMap({
        'type': 'object',
        'properties': {
          'a': {r'$ref': 'https://example.com/remote.json#/definitions/withDefault'},
        },
      });

      final seed = schemaSeedValue(schema, rootSchema: schema);

      expect(seed.present, isFalse);
    });
  });

  group(r'schemaSeedValue: defaults behind document-local $ref/allOf', () {
    // The sync counterpart of the resolver above: seeds are computed at
    // document extension points (and in the sync switch policy), where the
    // async resolveSchema pipeline is not available. Local `#/...` pointers
    // and allOf are expanded by schemaSeedValue itself, given the root
    // document via `rootSchema`.
    PresenceValue<Object?> seedOf(Map<String, Object?> rawSchema) {
      final schema = Schema.fromMap(rawSchema);
      return schemaSeedValue(schema, rootSchema: schema);
    }

    test(r'a default behind a property $ref (draft-07 definitions)', () {
      final seed = seedOf({
        'type': 'object',
        'definitions': {
          'withDefault': {'type': 'string', 'default': 'hidden'},
        },
        'properties': {
          'a': {r'$ref': '#/definitions/withDefault'},
        },
      });

      expect(seed.valueOrNull, {'a': 'hidden'});
    });

    test(r'without rootSchema the $ref is not followed (nothing to point into)', () {
      final seed = schemaSeedValue(
        Schema.fromMap({
          'type': 'object',
          r'$defs': {
            'withDefault': {'type': 'string', 'default': 'hidden'},
          },
          'properties': {
            'a': {r'$ref': r'#/$defs/withDefault'},
          },
        }),
      );

      expect(seed.present, isFalse);
    });

    test(r'a $ref chain is followed to the end', () {
      final seed = seedOf({
        'type': 'object',
        r'$defs': {
          'named': {'type': 'string', 'default': 'from-def'},
          'alias': {r'$ref': r'#/$defs/named'},
        },
        'properties': {
          'a': {r'$ref': r'#/$defs/alias'},
        },
      });

      expect(seed.valueOrNull, {'a': 'from-def'});
    });

    test('a local sibling default overrides the referenced one (resolver parity)', () {
      final seed = seedOf({
        'type': 'object',
        r'$defs': {
          'named': {'type': 'string', 'default': 'from-def'},
        },
        'properties': {
          'a': {r'$ref': r'#/$defs/named', 'default': 'local-wins'},
        },
      });

      expect(seed.valueOrNull, {'a': 'local-wins'});
    });

    test(r'a const behind a $ref wins over defaults', () {
      final seed = seedOf({
        'type': 'object',
        r'$defs': {
          'pinned': {'type': 'string', 'const': 'pinned'},
        },
        'properties': {
          'a': {r'$ref': r'#/$defs/pinned'},
        },
      });

      expect(seed.valueOrNull, {'a': 'pinned'});
    });

    test('allOf branches are flattened, defaults collected from all of them', () {
      final seed = seedOf({
        'type': 'object',
        r'$defs': {
          'addressBase': {
            'type': 'object',
            'properties': {
              'country': {'type': 'string', 'default': 'DE'},
            },
          },
        },
        'properties': {
          'address': {
            'allOf': [
              {r'$ref': r'#/$defs/addressBase'},
              {
                'properties': {
                  'city': {'type': 'string', 'default': 'Berlin'},
                },
              },
            ],
          },
        },
      });

      expect(seed.valueOrNull, {
        'address': {'country': 'DE', 'city': 'Berlin'},
      });
    });

    test('a recursive schema terminates: one level expanded, the cycle is cut', () {
      final seed = seedOf({
        'type': 'object',
        r'$defs': {
          'node': {
            'type': 'object',
            'properties': {
              'label': {'type': 'string', 'default': 'leaf'},
              'next': {r'$ref': r'#/$defs/node'},
            },
          },
        },
        'properties': {
          'recursive': {r'$ref': r'#/$defs/node'},
        },
      });

      expect(seed.valueOrNull, {
        'recursive': {'label': 'leaf'},
      });
    });

    test('sibling properties referencing the same def both get the seed', () {
      // The visited-refs cycle guard is scoped per descent branch, not
      // shared across siblings.
      final seed = seedOf({
        'type': 'object',
        r'$defs': {
          'named': {'type': 'string', 'default': 'from-def'},
        },
        'properties': {
          'a': {r'$ref': r'#/$defs/named'},
          'b': {r'$ref': r'#/$defs/named'},
        },
      });

      expect(seed.valueOrNull, {'a': 'from-def', 'b': 'from-def'});
    });

    test('the whole zoo in one document (integration case)', () {
      final seed = seedOf({
        'type': 'object',
        r'$defs': {
          'namedThing': {'type': 'string', 'default': 'from-def'},
          'aliasedThing': {r'$ref': r'#/$defs/namedThing'},
          'pinnedThing': {'type': 'string', 'const': 'pinned'},
          'addressBase': {
            'type': 'object',
            'properties': {
              'country': {'type': 'string', 'default': 'DE'},
            },
          },
          'node': {
            'type': 'object',
            'properties': {
              'label': {'type': 'string', 'default': 'leaf'},
              'next': {r'$ref': r'#/$defs/node'},
            },
          },
        },
        'properties': {
          'plainDefault': {'type': 'string', 'default': 'plain'},
          'behindRef': {r'$ref': r'#/$defs/namedThing'},
          'behindRefChain': {r'$ref': r'#/$defs/aliasedThing'},
          'refOverridden': {r'$ref': r'#/$defs/namedThing', 'default': 'local-wins'},
          'constBehindRef': {r'$ref': r'#/$defs/pinnedThing'},
          'mergedByAllOf': {
            'allOf': [
              {r'$ref': r'#/$defs/addressBase'},
              {
                'properties': {
                  'city': {'type': 'string', 'default': 'Berlin'},
                },
              },
            ],
          },
          'recursive': {r'$ref': r'#/$defs/node'},
          'noSeed': {'type': 'string'},
        },
      });

      expect(seed.valueOrNull, {
        'plainDefault': 'plain',
        'behindRef': 'from-def',
        'behindRefChain': 'from-def',
        'refOverridden': 'local-wins',
        'constBehindRef': 'pinned',
        'mergedByAllOf': {'country': 'DE', 'city': 'Berlin'},
        'recursive': {'label': 'leaf'},
        // 'noSeed' is absent: the schema prescribes nothing for it.
      });
    });
  });
}

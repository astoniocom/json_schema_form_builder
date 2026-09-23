// The sample catalog of the demo. A number of samples are taken or adapted
// from the react-jsonschema-form (RJSF) playground
// (https://github.com/rjsf-team/react-jsonschema-form, Apache-2.0), which
// doubles as a compatibility reference: the same schemas can be compared
// side by side in both libraries.
import 'package:json_schema_form_builder/json_schema_form_builder.dart';

import 'models.dart';

final samples = <Sample>[
  const Sample(
    title: 'Simple',
    category: SampleCategory.basics,
    jsonSchema: {
      'title': 'A registration form',
      'description': 'A simple form example.',
      'type': 'object',
      'required': ['firstName', 'lastName'],
      'properties': {
        'firstName': {'type': 'string', 'title': 'First name', 'default': 'Chuck'},
        'lastName': {'type': 'string', 'title': 'Last name'},
        'age': {'type': 'integer', 'title': 'Age'},
        'bio': {'type': 'string', 'title': 'Bio'},
        'password': {'type': 'string', 'title': 'Password', 'minLength': 3},
        'telephone': {'type': 'string', 'title': 'Telephone', 'minLength': 10},
      },
    },
    formData: PresenceValue({
      'firstName': 'Chuck',
      'lastName': 'Norris',
      'age': 75,
      'bio': 'Roundhouse kicking asses since 1940',
      'password': 'noneed',
      'telephone': '1-800-KICKASS',
    }),
  ),
  const Sample(
    title: 'Nested',
    category: SampleCategory.basics,
    jsonSchema: {
      'title': 'A list of tasks',
      'type': 'object',
      'required': ['title'],
      'properties': {
        'title': {'type': 'string', 'title': 'Task list title'},
        'tasks': {
          'type': 'array',
          'title': 'Tasks',
          'items': {
            'type': 'object',
            'required': ['title'],
            'properties': {
              'title': {'type': 'string', 'title': 'Title', 'description': 'A sample title'},
              'details': {'type': 'string', 'title': 'Task details', 'description': 'Enter the task details'},
              'done': {'type': 'boolean', 'title': 'Done?', 'default': false},
            },
          },
        },
      },
    },
    formData: PresenceValue({
      'title': 'My current tasks',
      'tasks': [
        {
          'title': 'My first task',
          'details': 'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
          'done': true,
        },
        {
          'title': 'My second task',
          'details': 'Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur',
          'done': false,
        },
      ],
    }),
  ),
  const Sample(
    title: 'Arrays',
    category: SampleCategory.arrays,
    jsonSchema: {
      'definitions': {
        'Thing': {
          'type': 'object',
          'properties': {
            'name': {'type': 'string', 'default': 'Default name'},
          },
        },
      },
      'type': 'object',
      'properties': {
        'listOfStrings': {
          'type': 'array',
          'title': 'A list of strings',
          'items': {'type': 'string', 'default': 'bazinga'},
        },
        'multipleChoicesList': {
          'type': 'array',
          'title': 'A multiple choices list',
          'items': {
            'type': 'string',
            'enum': ['foo', 'bar', 'fuzz', 'qux'],
          },
          'uniqueItems': true,
        },
        'fixedItemsList': {
          'type': 'array',
          'title': 'A list of fixed items',
          'prefixItems': [
            {'title': 'A string value', 'type': 'string', 'default': 'lorem ipsum'},
            {'title': 'a boolean value', 'type': 'boolean'},
          ],
          'items': {'title': 'Additional item', 'type': 'number'},
        },
        'minItemsList': {
          'type': 'array',
          'title': 'A list with a minimal number of items',
          'minItems': 3,
          'items': {r'$ref': '#/definitions/Thing'},
        },
        'defaultsAndMinItems': {
          'type': 'array',
          'title': 'List and item level defaults',
          'minItems': 5,
          'default': ['carp', 'trout', 'bream'],
          'items': {'type': 'string', 'default': 'unidentified'},
        },
        'nestedList': {
          'type': 'array',
          'title': 'Nested list',
          'items': {
            'type': 'array',
            'title': 'Inner list',
            'items': {'type': 'string', 'default': 'lorem ipsum'},
          },
        },
      },
    },
    formData: PresenceValue({
      'listOfStrings': ['foo', 'bar'],
      'multipleChoicesList': ['foo', 'bar'],
      'fixedItemsList': ['Some text', true, 123],
      'minItemsList': [
        {'name': 'Default name'},
        {'name': 'Default name'},
        {'name': 'Default name'},
      ],
      'defaultsAndMinItems': ['carp', 'trout', 'bream', 'unidentified', 'unidentified'],
      'nestedList': [
        ['lorem', 'ipsum'],
        ['dolor'],
      ],
    }),
  ),
  const Sample(
    title: 'Fixed items (tuple)',
    category: SampleCategory.arrays,
    jsonSchema: {
      'type': 'array',
      'title': 'A list of fixed items',
      'prefixItems': [
        {'title': 'A string value', 'type': 'string', 'default': 'lorem ipsum'},
        {'title': 'a boolean value', 'type': 'boolean'},
      ],
      'items': {'title': 'Additional item', 'type': 'number'},
    },
    formData: PresenceValue(['lorem ipsum', true, 5]),
  ),
  // The draft-07 tuple spelling: `items` as a LIST of positional schemas
  // plus `additionalItems` for the rest. Rendering reads it natively, and
  // validation rewrites it into the 2020-12 prefixItems/items form
  // (normalizeDraft07Tuples) — the two tuple samples behave identically.
  const Sample(
    title: 'Fixed items (draft-07 tuple)',
    category: SampleCategory.arrays,
    jsonSchema: {
      'type': 'array',
      'title': 'A draft-07 list of fixed items',
      'items': [
        {'title': 'A string value', 'type': 'string', 'default': 'lorem ipsum'},
        {'title': 'a boolean value', 'type': 'boolean'},
      ],
      'additionalItems': {'title': 'Additional item', 'type': 'number'},
    },
    formData: PresenceValue(['lorem ipsum', true, 5]),
  ),
  const Sample(
    title: 'Array at root',
    category: SampleCategory.arrays,
    jsonSchema: {
      'type': 'array',
      'items': {'type': 'string', 'title': 'Item'},
    },
    formData: PresenceValue(['f', 's']),
  ),
  const Sample(
    title: 'Array of refs',
    category: SampleCategory.arrays,
    jsonSchema: {
      'definitions': {
        'item': {
          'type': 'object',
          'properties': {
            'name': {'type': 'string'},
          },
        },
      },
      'type': 'array',
      'items': {r'$ref': '#/definitions/item'},
    },
    formData: PresenceValue([]),
  ),
  const Sample(
    title: 'Numbers',
    category: SampleCategory.basics,
    jsonSchema: {
      'type': 'object',
      'title': 'Number fields & widgets',
      'properties': {
        'number': {'title': 'Number', 'type': 'number'},
        'integer': {'title': 'Integer', 'type': 'integer'},
        'numberEnum': {
          'type': 'number',
          'title': 'Number enum',
          'enum': [1, 2, 3],
        },
        'numberEnumRadio': {
          'type': 'number',
          'title': 'Number enum',
          'enum': [1, 2, 3],
        },
        'integerRange': {'title': 'Integer range', 'type': 'integer', 'minimum': -50, 'maximum': 50},
        'integerRangeSteps': {'title': 'Integer range (by 10)', 'type': 'integer', 'minimum': 50, 'maximum': 100, 'multipleOf': 10},
      },
    },
    formData: PresenceValue({'number': 3.14, 'integer': 42, 'numberEnum': 2, 'integerRange': 42, 'integerRangeSteps': 80}),
  ),

  const Sample(
    title: 'Read only',
    category: SampleCategory.basics,
    jsonSchema: {
      'title': 'Read-only fields',
      'description': 'readOnly on a scalar, and propagating from an object and a list to their children.',
      'type': 'object',
      'properties': {
        'scalar': {'type': 'string', 'title': 'Read-only string', 'readOnly': true, 'default': 'I am read-only.'},
        'object': {
          'type': 'object',
          'title': 'Read-only object',
          'readOnly': true,
          'properties': {
            'name': {'type': 'string'},
            'age': {'type': 'integer'},
          },
        },
        'list': {
          'type': 'array',
          'title': 'Read-only list',
          'readOnly': true,
          'items': {'type': 'string'},
        },
      },
    },
    formData: PresenceValue({
      'scalar': 'I am read-only.',
      'object': {'name': 'Chuck', 'age': 75},
      'list': ['one', 'two'],
    }),
  ),
  const Sample(
    title: 'Any Of (refs)',
    category: SampleCategory.combinators,
    jsonSchema: {
      'definitions': {
        'personType': {
          'type': 'object',
          'properties': {
            'name': {'type': 'string'},
            'details': {'type': 'string'},
          },
        },
        'companyType': {
          'type': 'object',
          'properties': {
            'name': {'type': 'string'},
            'details': {'type': 'string'},
          },
        },
      },
      'type': 'object',
      'properties': {
        'contact': {
          'title': 'Contact (anyOf with same property names)',
          'anyOf': [
            {'title': 'Person', r'$ref': '#/definitions/personType'},
            {'title': 'Company', r'$ref': '#/definitions/companyType'},
          ],
        },
      },
    },
    formData: PresenceValue({
      'contact': {'name': 'Jane Smith', 'details': 'Software engineer'},
    }),
  ),
  const Sample(
    title: 'References',
    category: SampleCategory.references,
    jsonSchema: {
      'definitions': {
        'address': {
          'type': 'object',
          'properties': {
            'street_address': {'type': 'string'},
            'city': {'type': 'string'},
            'state': {'type': 'string'},
          },
          'required': ['street_address', 'city', 'state'],
        },
        'node': {
          'type': 'object',
          'properties': {
            'name': {'type': 'string'},
            'children': {
              'type': 'array',
              'items': {
                'oneOf': [
                  {'title': 'None', 'type': 'null'},
                  {r'$ref': '#/definitions/node'},
                ],
              },
            },
          },
        },
        'personType': {
          'type': 'object',
          'properties': {
            'name': {'type': 'string'},
            'details': {'type': 'string'},
          },
        },
        'companyType': {
          'type': 'object',
          'properties': {
            'name': {'type': 'string'},
            'details': {'type': 'string'},
          },
        },
      },
      'type': 'object',
      'properties': {
        'billing_address': {'title': 'Billing address', r'$ref': '#/definitions/address'},
        'shipping_address': {'title': 'Shipping address', r'$ref': '#/definitions/address'},
        'tree': {'title': 'Recursive references', r'$ref': '#/definitions/node'},
        'contact': {
          'title': 'Contact (oneOf with same property names)',
          'oneOf': [
            {'title': 'Person', r'$ref': '#/definitions/personType'},
            {'title': 'Company', r'$ref': '#/definitions/companyType'},
          ],
        },
      },
    },
    formData: PresenceValue({
      'billing_address': {'street_address': '21, Jump Street', 'city': 'Babel', 'state': 'Neverland'},
      'shipping_address': {'street_address': '221B, Baker Street', 'city': 'London', 'state': 'N/A'},
      'tree': {
        'name': 'root',
        'children': [
          {'name': 'leaf'},
        ],
      },
      'contact': {'name': 'Jane Smith', 'details': 'Software engineer'},
    }),
  ),
  const Sample(
    title: 'Recursive References',
    category: SampleCategory.references,
    jsonSchema: {
      'definitions': {
        'node': {
          'type': 'object',
          'properties': {
            'name': {'type': 'string'},
            'children': {
              'type': 'array',
              'items': {
                'oneOf': [
                  {'title': 'None', 'type': 'null'},
                  {r'$ref': '#/definitions/node'},
                ],
              },
            },
          },
        },
      },
      'type': 'object',
      'properties': {
        'tree': {'title': 'Recursive references', r'$ref': '#/definitions/node'},
      },
    },
    formData: PresenceValue({}),
  ),
  const Sample(
    title: 'Recursive References 2',
    category: SampleCategory.references,
    jsonSchema: {
      'definitions': {
        'node': {
          'type': 'object',
          'properties': {
            'name': {'type': 'string'},
            'children': {
              'type': 'array',
              'items': {r'$ref': '#/definitions/node'},
            },
          },
        },
      },
      'type': 'object',
      'properties': {
        'tree': {'title': 'Recursive references', r'$ref': '#/definitions/node'},
      },
    },
    formData: PresenceValue({}),
  ),
  // A schema recursing through OBJECT properties (node -> next -> node),
  // with no array or nullable oneOf to stop the descent. The registry's
  // cycle guard collapses the valueless repeat into an "Expand cycle"
  // button; each press reveals one more level.
  const Sample(
    title: 'Recursive object (cycle guard)',
    category: SampleCategory.references,
    jsonSchema: {
      r'$defs': {
        'node': {
          'type': 'object',
          'properties': {
            'label': {'type': 'string'},
            'next': {r'$ref': r'#/$defs/node'},
          },
        },
      },
      'type': 'object',
      'title': 'Linked list',
      'properties': {
        'head': {'title': 'Head', r'$ref': r'#/$defs/node'},
      },
    },
    formData: PresenceValue({}),
  ),
  // Defaults hidden behind document-local $refs and allOf are collected when
  // the document is extended: add an item to the array and the new contact
  // comes pre-filled (name/city from `default`s behind $refs, zip from an
  // allOf branch, kind pinned by `const`).
  const Sample(
    title: 'Defaults behind refs',
    category: SampleCategory.references,
    jsonSchema: {
      r'$defs': {
        'country': {'type': 'string', 'default': 'DE'},
        'address': {
          'type': 'object',
          'properties': {
            'country': {r'$ref': r'#/$defs/country'},
            'city': {'type': 'string', 'default': 'Berlin'},
          },
        },
        'contact': {
          'type': 'object',
          'properties': {
            'kind': {'type': 'string', 'const': 'personal'},
            'name': {'type': 'string', 'default': 'New contact'},
            'address': {
              'allOf': [
                {r'$ref': r'#/$defs/address'},
                {
                  'properties': {
                    'zip': {'type': 'string', 'default': '10115'},
                  },
                },
              ],
            },
          },
        },
      },
      'type': 'object',
      'title': 'Defaults behind refs',
      'properties': {
        'contacts': {
          'type': 'array',
          'items': {r'$ref': r'#/$defs/contact'},
        },
      },
    },
    formData: PresenceValue({'contacts': []}),
  ),
  const Sample(
    title: 'Errors',
    category: SampleCategory.validation,
    jsonSchema: {
      'title': 'Contextualized errors',
      'type': 'object',
      'properties': {
        'firstName': {'type': 'string', 'title': 'First name', 'minLength': 8, 'pattern': r'\d+'},
        'active': {'type': 'boolean', 'title': 'Active'},
        'skills': {
          'type': 'array',
          'items': {'type': 'string', 'minLength': 5},
        },
        'multipleChoicesList': {
          'type': 'array',
          'title': 'Pick max two items',
          'uniqueItems': true,
          'maxItems': 2,
          'items': {
            'type': 'string',
            'enum': ['foo', 'bar', 'fuzz'],
          },
        },
      },
    },
    formData: PresenceValue({
      'firstName': 'Chuck',
      'active': 'wrong',
      'skills': ['karate', 'budo', 'aikido'],
      'multipleChoicesList': ['foo', 'bar', 'fuzz'],
    }),
  ),
  const Sample(
    title: 'Examples',
    category: SampleCategory.basics,
    jsonSchema: {
      'title': 'Examples',
      'description': 'A text field with example values.',
      'type': 'object',
      'properties': {
        'browser': {
          'type': 'string',
          'title': 'Browser',
          'examples': ['Firefox', 'Chrome', 'Opera', 'Vivaldi', 'Safari'],
        },
        'version': {
          'type': 'number',
          'title': 'Version',
          'examples': [1, 2, 3, 4, 5],
        },
      },
    },
    formData: PresenceValue({}),
  ),
  Sample(
    title: 'Large',
    category: SampleCategory.misc,
    jsonSchema: {
      'definitions': {
        'largeEnum': {
          'type': 'string',
          'enum': [for (var i = 0; i < 100; i++) 'option #$i'],
        },
      },
      'title': 'A rather large form',
      'type': 'object',
      'properties': {
        'string': {'type': 'string', 'title': 'Some string'},
        'choice1': {r'$ref': '#/definitions/largeEnum'},
        'choice2': {r'$ref': '#/definitions/largeEnum'},
        'choice3': {r'$ref': '#/definitions/largeEnum'},
        'choice4': {r'$ref': '#/definitions/largeEnum'},
        'choice5': {r'$ref': '#/definitions/largeEnum'},
        'choice6': {r'$ref': '#/definitions/largeEnum'},
        'choice7': {r'$ref': '#/definitions/largeEnum'},
        'choice8': {r'$ref': '#/definitions/largeEnum'},
        'choice9': {r'$ref': '#/definitions/largeEnum'},
        'choice10': {r'$ref': '#/definitions/largeEnum'},
      },
    },
    formData: const PresenceValue({}),
  ),
  const Sample(
    title: 'Date and time',
    category: SampleCategory.basics,
    jsonSchema: {
      'title': 'Date and time widgets',
      'type': 'object',
      'properties': {
        'datetime': {'type': 'string', 'format': 'date-time'},
        'date': {'type': 'string', 'format': 'date'},
        'time': {'type': 'string', 'format': 'time'},
      },
    },
    formData: PresenceValue({}),
  ),
  const Sample(
    title: 'Validation',
    category: SampleCategory.validation,
    jsonSchema: {
      'title': 'Custom validation',
      'description': 'Constraint validation: a required field, minLength and minimum.',
      'type': 'object',
      'required': ['firstName'],
      'properties': {
        'firstName': {'title': 'First Name', 'type': 'string'},
        'pass1': {'title': 'Password', 'type': 'string', 'minLength': 3},
        'pass2': {'title': 'Repeat password', 'type': 'string', 'minLength': 3},
        'age': {'title': 'Age', 'type': 'integer', 'minimum': 18},
      },
    },
    formData: PresenceValue({}),
  ),
  const Sample(
    title: 'Files',
    category: SampleCategory.basics,
    jsonSchema: {
      'title': 'Files',
      'type': 'object',
      'properties': {
        'file': {'type': 'string', 'format': 'data-url', 'title': 'Single file'},
        'files': {
          'type': 'array',
          'title': 'Multiple files',
          'items': {'type': 'string', 'format': 'data-url'},
        },
        'filesAccept': {'type': 'string', 'format': 'data-url', 'title': 'Single File with Accept attribute'},
      },
    },
    formData: PresenceValue({}),
  ),
  const Sample(
    title: 'Single',
    category: SampleCategory.basics,
    jsonSchema: {'title': 'A single-field form', 'type': 'string'},
    formData: PresenceValue('initial value'),
  ),
  const Sample(
    title: 'Alternatives',
    category: SampleCategory.combinators,
    jsonSchema: {
      'definitions': {
        'Color': {
          'title': 'Color',
          'type': 'string',
          'anyOf': [
            {
              'type': 'string',
              'enum': ['#ff0000'],
              'title': 'Red',
            },
            {
              'type': 'string',
              'enum': ['#00ff00'],
              'title': 'Green',
            },
            {
              'type': 'string',
              'enum': ['#0000ff'],
              'title': 'Blue',
            },
          ],
        },
        'Toggle': {
          'title': 'Toggle',
          'type': 'boolean',
          'oneOf': [
            {'title': 'Enable', 'const': true},
            {'title': 'Disable', 'const': false},
          ],
        },
      },
      'title': 'Image editor',
      'type': 'object',
      'required': ['currentColor', 'colorMask', 'blendMode'],
      'properties': {
        'currentColor': {r'$ref': '#/definitions/Color', 'title': 'Brush color'},
        'colorMask': {
          'type': 'array',
          'uniqueItems': true,
          'items': {r'$ref': '#/definitions/Color'},
          'title': 'Color mask',
        },
        'toggleMask': {'title': 'Apply color mask', r'$ref': '#/definitions/Toggle'},
        'colorPalette': {
          'type': 'array',
          'title': 'Color palette',
          'items': {r'$ref': '#/definitions/Color'},
        },
        'blendMode': {
          'title': 'Blend mode',
          'type': 'string',
          'oneOf': [
            {'const': 'screen', 'title': 'Screen'},
            {'const': 'multiply', 'title': 'Multiply'},
            {'const': 'overlay', 'title': 'Overlay'},
          ],
        },
      },
    },
    formData: PresenceValue({
      'currentColor': '#00ff00',
      'colorMask': ['#0000ff'],
      'toggleMask': true,
      'colorPalette': ['#ff0000'],
      'blendMode': 'screen',
    }),
  ),
  const Sample(
    title: 'Property dependencies',
    category: SampleCategory.dependencies,
    jsonSchema: {
      'title': 'Property dependencies',
      'description': 'These samples are best viewed without live validation.',
      'type': 'object',
      'properties': {
        'unidirectional': {
          'title': 'Unidirectional',
          'type': 'object',
          'properties': {
            'name': {'type': 'string'},
            'credit_card': {'type': 'integer'},
            'billing_address': {'type': 'string'},
          },
          'required': ['name'],
          'dependencies': {
            'credit_card': ['billing_address'],
          },
        },
        'bidirectional': {
          'title': 'Bidirectional',
          'description': 'Dependencies are not bidirectional, you can, of course, define the bidirectional dependencies explicitly.',
          'type': 'object',
          'properties': {
            'name': {'type': 'string'},
            'credit_card': {'type': 'integer'},
            'billing_address': {'type': 'string'},
          },
          'required': ['name'],
          'dependencies': {
            'credit_card': ['billing_address'],
            'billing_address': ['credit_card'],
          },
        },
      },
    },
    formData: PresenceValue({
      'unidirectional': {'name': 'Tim'},
      'bidirectional': {'name': 'Jill'},
    }),
  ),
  const Sample(
    title: 'Schema dependencies',
    category: SampleCategory.dependencies,
    jsonSchema: {
      'title': 'Schema dependencies',
      'description': 'These samples are best viewed without live validation.',
      'type': 'object',
      'properties': {
        'simple': {
          'title': 'Simple',
          'type': 'object',
          'properties': {
            'name': {'type': 'string'},
            'credit_card': {'type': 'integer'},
          },
          'required': ['name'],
          'dependencies': {
            'credit_card': {
              'properties': {
                'billing_address': {'type': 'string'},
              },
              'required': ['billing_address'],
            },
          },
        },
        'conditional': {'title': 'Conditional', r'$ref': '#/definitions/person'},
        'arrayOfConditionals': {
          'title': 'Array of conditionals',
          'type': 'array',
          'items': {r'$ref': '#/definitions/person'},
        },
        'fixedArrayOfConditionals': {
          'title': 'Fixed array of conditionals',
          'type': 'array',
          'prefixItems': [
            {'title': 'Primary person', r'$ref': '#/definitions/person'},
          ],
          'items': {'title': 'Additional person', r'$ref': '#/definitions/person'},
        },
      },
      'definitions': {
        'person': {
          'title': 'Person',
          'type': 'object',
          'properties': {
            'Do you have any pets?': {
              'type': 'string',
              'enum': ['No', 'Yes: One', 'Yes: More than one'],
              'default': 'No',
            },
          },
          'required': ['Do you have any pets?'],
          'dependencies': {
            'Do you have any pets?': {
              'oneOf': [
                {
                  'properties': {
                    'Do you have any pets?': {
                      'enum': ['No'],
                    },
                  },
                },
                {
                  'properties': {
                    'Do you have any pets?': {
                      'enum': ['Yes: One'],
                    },
                    'How old is your pet?': {'type': 'number'},
                  },
                  'required': ['How old is your pet?'],
                },
                {
                  'properties': {
                    'Do you have any pets?': {
                      'enum': ['Yes: More than one'],
                    },
                    'Do you want to get rid of any?': {'type': 'boolean'},
                  },
                  'required': ['Do you want to get rid of any?'],
                },
              ],
            },
          },
        },
      },
    },
    formData: PresenceValue({
      'simple': {'name': 'Randy'},
      'conditional': {'Do you have any pets?': 'No'},
      'arrayOfConditionals': [
        {'Do you have any pets?': 'Yes: One', 'How old is your pet?': 6},
        {'Do you have any pets?': 'Yes: More than one', 'Do you want to get rid of any?': false},
      ],
      'fixedArrayOfConditionals': [
        {'Do you have any pets?': 'No'},
        {'Do you have any pets?': 'Yes: One', 'How old is your pet?': 6},
        {'Do you have any pets?': 'Yes: More than one', 'Do you want to get rid of any?': true},
      ],
    }),
  ),
  const Sample(
    title: 'Additional properties',
    category: SampleCategory.objects,
    jsonSchema: {
      'title': 'Additional properties',
      'description': 'Objects accepting keys beyond the declared properties.',
      'type': 'object',
      'properties': {
        'anySchema': {
          'type': 'object',
          'title': 'additionalProperties: true',
          'additionalProperties': true,
          'properties': {
            'firstName': {'type': 'string', 'title': 'First name'},
          },
        },
        'typed': {
          'type': 'object',
          'title': 'additionalProperties as schema (string, 2-4 chars)',
          'additionalProperties': {'type': 'string', 'minLength': 2, 'maxLength': 4},
          'properties': {
            'firstName': {'type': 'string', 'title': 'First name'},
          },
        },
      },
    },
    formData: PresenceValue({
      'anySchema': {'firstName': 'Chuck', 'assKickCount': 'infinity'},
      'typed': {'firstName': 'Chuck', 'kick': 'yes'},
    }),
  ),
  const Sample(
    title: 'Pattern properties',
    category: SampleCategory.objects,
    jsonSchema: {
      'title': 'A customizable registration form',
      'description': 'A simple form with pattern properties example.',
      'type': 'object',
      'required': ['firstName', 'lastName'],
      'properties': {
        'firstName': {'type': 'string', 'title': 'First name'},
        'lastName': {'type': 'string', 'title': 'Last name'},
      },
      'patternProperties': {
        r'^[a-z][a-zA-Z]+$': {'type': 'string'},
      },
    },
    formData: PresenceValue({'firstName': 'Chuck', 'lastName': 'Norris', 'assKickCount': 'infinity'}),
  ),

  const Sample(
    title: 'Any of (minimal)',
    category: SampleCategory.combinators,
    jsonSchema: {
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
  ),

  const Sample(
    title: 'Any of',
    category: SampleCategory.combinators,
    jsonSchema: {
      'type': 'object',
      'properties': {
        'age': {'type': 'integer', 'title': 'Age'},
        'items': {
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
        },
      },
      'anyOf': [
        {
          'title': 'First method of identification',
          'properties': {
            'firstName': {'type': 'string', 'title': 'First name', 'default': 'Chuck'},
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
    },
    formData: PresenceValue({'firstName': 'Chuck'}),
  ),
  const Sample(
    title: 'Any of (Location)',
    category: SampleCategory.combinators,
    jsonSchema: {
      'title': 'Location',
      'type': 'object',
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
    },
    formData: PresenceValue({}),
  ),

  const Sample(
    title: 'Any of (scalar branches)',
    category: SampleCategory.combinators,
    jsonSchema: {
      'type': 'object',
      'properties': {
        'age': {'type': 'integer', 'title': 'Age'},
      },
      'anyOf': [
        {'title': 'First method of identification (str)', 'type': 'string'},
        {'title': 'Second method of identification (int)', 'type': 'integer'},
      ],
    },
  ),
  const Sample(
    title: 'One of',
    category: SampleCategory.combinators,
    jsonSchema: {
      'type': 'object',
      'oneOf': [
        {
          'properties': {
            'lorem': {'type': 'string'},
          },
          'required': ['lorem'],
        },
        {
          'properties': {
            'ipsum': {'type': 'string'},
          },
          'required': ['ipsum'],
        },
      ],
    },
    formData: PresenceValue({'ipsum': 'should be second selected'}),
  ),
  const Sample(
    title: 'All of',
    category: SampleCategory.combinators,
    jsonSchema: {
      'type': 'object',
      'allOf': [
        {
          'properties': {
            'lorem': {
              'type': ['string', 'boolean'],
              'default': true,
            },
          },
        },
        {
          'properties': {
            'lorem': {'type': 'boolean'},
            'ipsum': {'type': 'string'},
          },
        },
      ],
    },
    formData: PresenceValue({'lorem': true}),
  ),
  const Sample(
    title: 'If then else',
    category: SampleCategory.combinators,
    jsonSchema: {
      'type': 'object',
      'properties': {
        'animal': {
          'enum': ['Cat', 'Fish'],
        },
      },
      'allOf': [
        {
          'if': {
            'properties': {
              'animal': {'const': 'Cat'},
            },
            // 'required': ['animal'],
          },
          'then': {
            'properties': {
              'food': {
                'type': 'string',
                'enum': ['meat', 'grass', 'fish'],
              },
            },
            'required': ['food'],
          },
        },
        {
          'if': {
            'properties': {
              'animal': {'const': 'Fish'},
            },
            // 'required': ['animal'],
          },
          'then': {
            'properties': {
              'food': {
                'type': 'string',
                'enum': ['insect', 'worms'],
              },
              'water': {
                'type': 'string',
                'enum': ['lake', 'sea'],
              },
            },
            'required': ['food', 'water'],
          },
        },
        {
          'required': ['animal'],
        },
      ],
    },
    formData: PresenceValue({}),
  ),
  const Sample(
    title: 'Null fields',
    category: SampleCategory.misc,
    jsonSchema: {
      'title': 'Null field example',
      'description': 'A short form with a null field',
      'type': 'object',
      'required': ['firstName'],
      'properties': {
        'helpText': {'title': 'A null field', 'description': 'Null fields like this are great for adding extra information', 'type': 'null'},
        'firstName': {'type': 'string', 'title': 'A regular string field', 'default': 'Chuck'},
      },
    },
    formData: PresenceValue({'helpText': null, 'firstName': 'Chuck'}),
  ),
  const Sample(
    title: 'Enumerated objects',
    category: SampleCategory.objects,
    jsonSchema: {
      'definitions': {
        'locations': {
          'enum': [
            {'name': 'New York', 'lat': 40, 'lon': 74},
            {'name': 'Amsterdam', 'lat': 52, 'lon': 5},
            {'name': 'Hong Kong', 'lat': 22, 'lon': 114},
          ],
        },
      },
      'type': 'object',
      'properties': {
        'location': {'title': 'Location', r'$ref': '#/definitions/locations'},
        'locationRadio': {'title': 'Location Radio', r'$ref': '#/definitions/locations'},
        'multiSelect': {
          'title': 'Locations',
          'type': 'array',
          'uniqueItems': true,
          'items': {r'$ref': '#/definitions/locations'},
        },
        'checkboxes': {
          'title': 'Locations Checkboxes',
          'type': 'array',
          'uniqueItems': true,
          'items': {r'$ref': '#/definitions/locations'},
        },
        'rating': {
          'title': 'Rating (number enum)',
          'type': 'number',
          'enum': [1, 2, 3, 4, 5],
        },
        'priority': {
          'title': 'Priority (string enum)',
          'type': 'string',
          'enum': ['low', 'medium', 'high', 'critical'],
        },
      },
    },
    formData: PresenceValue({
      'location': {'name': 'Amsterdam', 'lat': 52, 'lon': 5},
    }),
  ),
  const Sample(
    title: 'Nullable',
    category: SampleCategory.misc,
    jsonSchema: {
      'title': 'A registration form (nullable)',
      'description': 'A simple form example using nullable types',
      'type': 'object',
      'required': ['firstName', 'lastName'],
      'properties': {
        'firstName': {'type': 'string', 'title': 'First name', 'default': 'Chuck'},
        'lastName': {'type': 'string', 'title': 'Last name'},
        'age': {
          'type': ['integer', 'null'],
          'title': 'Age',
        },
        'bio': {
          'type': ['string', 'null'],
          'title': 'Bio',
        },
        'password': {'type': 'string', 'title': 'Password', 'minLength': 3},
        'telephone': {'type': 'string', 'title': 'Telephone', 'minLength': 10},
      },
    },
    formData: PresenceValue({'firstName': 'Chuck', 'lastName': 'Norris', 'age': 75, 'bio': null, 'password': 'noneed'}),
  ),
  const Sample(
    title: 'Defaults',
    category: SampleCategory.basics,
    jsonSchema: {
      'title': 'Schema default properties',
      'type': 'object',
      'properties': {
        'valuesInFormData': {'title': 'Values in form data', r'$ref': '#/definitions/defaultsExample'},
        'noValuesInFormData': {'title': 'No values in form data', r'$ref': '#/definitions/defaultsExample'},
      },
      'definitions': {
        'defaultsExample': {
          'type': 'object',
          'properties': {
            'scalar': {'title': 'Scalar', 'type': 'string', 'default': 'scalar default'},
            'array': {
              'title': 'Array',
              'type': 'array',
              'items': {
                'type': 'object',
                'properties': {
                  'nested': {'title': 'Nested array', 'type': 'string', 'default': 'nested array default'},
                },
              },
            },
            'object': {
              'title': 'Object',
              'type': 'object',
              'properties': {
                'nested': {'title': 'Nested object', 'type': 'string', 'default': 'nested object default'},
                'nested2': {'title': 'Nested object2', 'type': 'string', 'default': 'nested object default'},
              },
            },
          },
        },
      },
    },
    formData: PresenceValue({
      'valuesInFormData': {
        'scalar': 'value',
        'array': [
          {'nested': 'nested array value'},
        ],
        'object': {'nested': 'nested object value'},
      },
      'noValuesInFormData': {
        'scalar': 'scalar default',
        'array': [
          {'nested': 'nested array default'},
          {'nested': 'nested array default'},
        ],
        'object': {'nested': 'nested object default'},
      },
    }),
  ),
  const Sample(
    title: r'$id references',
    category: SampleCategory.references,
    jsonSchema: {
      'title': 'A registration form',
      'description': 'A custom-field form example.',
      'type': 'object',
      'definitions': {
        'specialString': {r'$id': '/schemas/specialString', 'type': 'string'},
      },
      'properties': {
        'mySpecialStringField': {r'$ref': '#/definitions/specialString'},
        'mySpecialStringArray': {
          'type': 'array',
          'items': {r'$ref': '#/definitions/specialString'},
        },
      },
    },
    formData: PresenceValue({'mySpecialStringField': 'special-text'}),
  ),
  const Sample(
    title: 'Employment (discriminator)',
    category: SampleCategory.combinators,
    jsonSchema: {
      'type': 'object',
      'properties': {
        'person': {'title': 'Person Info', r'$ref': '#/definitions/Person'},
        'employment': {
          'title': 'Employment',
          'discriminator': {'propertyName': 'job_type'},
          'oneOf': [
            {r'$ref': '#/definitions/Company'},
            {r'$ref': '#/definitions/Education'},
            {r'$ref': '#/definitions/Other'},
          ],
        },
      },
      'definitions': {
        'PersonName': {
          'type': 'object',
          'properties': {
            'first': {'title': 'First Name', 'minLength': 1, 'maxLength': 200, 'type': 'string'},
            'middle': {'title': 'Middle Name', 'minLength': 1, 'maxLength': 200, 'type': 'string'},
            'last': {'title': 'Last Name', 'minLength': 1, 'maxLength': 1000, 'type': 'string'},
          },
          'required': ['first', 'last'],
        },
        'Race': {
          'title': 'Race',
          'type': 'array',
          'items': {
            'type': 'string',
            'oneOf': [
              {'const': 'native_american', 'title': 'American Indian / Alaska Native'},
              {'const': 'asian', 'title': 'Asian'},
              {'const': 'black', 'title': 'Black / African American'},
              {'const': 'pacific_islander', 'title': 'Native Hawaiian / Other Pacific Islander'},
              {'const': 'white', 'title': 'White'},
            ],
          },
          'uniqueItems': true,
        },
        'Person': {
          'type': 'object',
          'properties': {
            'name': {r'$ref': '#/definitions/PersonName'},
            'birth_date': {'title': 'Date of Birth', 'type': 'string', 'format': 'date'},
            'race': {'title': 'Race', 'description': '(Check all that apply)', r'$ref': '#/definitions/Race'},
            'address': {'title': 'Address', r'$ref': '#/definitions/Address'},
          },
          'required': ['name', 'birth_date', 'race', 'address'],
        },
        'StateAbrv': {
          'title': 'StateAbrv',
          'enum': [
            'AL',
            'AK',
            'AS',
            'AZ',
            'AR',
            'CA',
            'CO',
            'CT',
            'DE',
            'DC',
            'FL',
            'GA',
            'GU',
            'HI',
            'ID',
            'IL',
            'IN',
            'IA',
            'KS',
            'KY',
            'LA',
            'ME',
            'MD',
            'MA',
            'MI',
            'MN',
            'MS',
            'MO',
            'MT',
            'NE',
            'NV',
            'NH',
            'NJ',
            'NM',
            'NY',
            'NC',
            'ND',
            'MP',
            'OH',
            'OK',
            'OR',
            'PA',
            'PR',
            'RI',
            'SC',
            'SD',
            'TN',
            'TX',
            'UT',
            'VT',
            'VA',
            'VI',
            'WA',
            'WV',
            'WI',
            'WY',
          ],
          'type': 'string',
        },
        'Address': {
          'type': 'object',
          'properties': {
            'line_1': {'title': 'Address', 'minLength': 1, 'maxLength': 200, 'type': 'string'},
            'line_2': {'title': 'Address 2', 'minLength': 1, 'maxLength': 200, 'type': 'string'},
            'city': {'title': 'City', 'minLength': 1, 'maxLength': 50, 'type': 'string'},
            'state': {'title': 'State', r'$ref': '#/definitions/StateAbrv'},
            'postal_code': {'title': 'ZIP Code', 'pattern': r'^\\d{5}(?:[-\\s]\\d{4})?$', 'type': 'string'},
          },
          'required': ['line_1', 'city', 'state', 'postal_code'],
        },
        'Location': {
          'type': 'object',
          'properties': {
            'city': {'title': 'City', 'type': 'string'},
            'state': {'title': 'State', r'$ref': '#/definitions/StateAbrv'},
          },
          'required': ['city', 'state'],
        },
        'Company': {
          'type': 'object',
          'properties': {
            'job_type': {
              'title': 'Company',
              'default': 'company',
              'enum': ['company'],
              'type': 'string',
            },
            'business': {'title': 'Company Name', 'type': 'string'},
            'title': {'title': 'Job Title', 'type': 'string'},
            'location': {r'$ref': '#/definitions/Location'},
          },
          'required': ['job_type', 'business', 'location'],
        },
        'Education': {
          'type': 'object',
          'properties': {
            'job_type': {
              'title': 'Education',
              'default': 'education',
              'enum': ['education'],
              'type': 'string',
            },
            'district': {'title': 'District Name', 'type': 'string'},
            'school': {'title': 'School Name', 'type': 'string'},
            'title': {'title': 'Job Title', 'type': 'string'},
            'location': {r'$ref': '#/definitions/Location'},
          },
          'required': ['job_type', 'school', 'location'],
        },
        'Other': {
          'type': 'object',
          'properties': {
            'job_type': {
              'title': 'Other',
              'default': 'other',
              'enum': ['other'],
              'type': 'string',
            },
            'description': {'title': 'Describe your job', 'type': 'string'},
          },
          'required': ['job_type', 'description'],
        },
      },
    },
    formData: PresenceValue({
      'person': {'name': {}, 'race': [], 'address': {}},
      'employment': {'job_type': 'company', 'location': {}},
    }),
  ),
  const Sample(
    title: 'Bundled schema',
    category: SampleCategory.references,
    jsonSchema: {
      r'$id': 'https://jsonschema.dev/schemas/examples/non-negative-integer-bundle',
      r'$schema': 'https://json-schema.org/draft/2020-12/schema',
      'description': 'Must be a non-negative integer',
      r'$defs': {
        'https://jsonschema.dev/schemas/mixins/integer': {
          r'$schema': 'https://json-schema.org/draft/2020-12/schema',
          r'$id': 'https://jsonschema.dev/schemas/mixins/integer',
          'description': 'Must be an integer',
          'type': 'integer',
        },
        'https://jsonschema.dev/schemas/mixins/non-negative': {
          r'$schema': 'https://json-schema.org/draft/2020-12/schema',
          r'$id': 'https://jsonschema.dev/schemas/mixins/non-negative',
          'description': 'Not allowed to be negative',
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
    },
    formData: PresenceValue({}),
  ),
  const Sample(
    title: 'Optional data controls',
    category: SampleCategory.objects,
    jsonSchema: {
      'title': 'test',
      'properties': {
        'nestedObjectOptional': {
          'type': 'object',
          'properties': {
            'test': {'type': 'string'},
            'deepObjectOptional': {
              'type': 'object',
              'properties': {
                'deepTest': {'type': 'string'},
              },
            },
            'deepObject': {
              'type': 'object',
              'properties': {
                'deepTest': {'type': 'string'},
              },
            },
            'deepArrayOptional': {
              'type': 'array',
              'items': {'type': 'string'},
            },
            'deepArrayOptional2': {
              'type': 'array',
              'items': {'type': 'string'},
            },
            'deepArray': {
              'type': 'array',
              'items': {'type': 'string'},
            },
          },
          'required': ['deepObject', 'deepArray'],
        },
        'nestedArrayOptional': {
          'type': 'array',
          'items': {'type': 'string'},
        },
        'nestedObject': {
          'type': 'object',
          'properties': {
            'test': {'type': 'string'},
          },
        },
        'nestedArray': {
          'type': 'array',
          'items': {'type': 'string'},
        },
        'optionalObjectWithOneofs': {
          'oneOf': [
            {
              'type': 'object',
              'properties': {
                'name': {'const': 'first_option'},
              },
              'required': ['name'],
            },
            {
              'type': 'object',
              'properties': {
                'name': {'const': 'second_option'},
                'flag': {'type': 'boolean', 'default': false},
              },
              'required': ['name'],
            },
            {
              'type': 'object',
              'properties': {
                'name': {'const': 'third_option'},
                'flag': {'type': 'boolean', 'default': false},
                'inner_obj': {
                  'type': 'object',
                  'properties': {
                    'foo': {'type': 'string'},
                  },
                },
              },
              'required': ['name'],
            },
          ],
        },
        'optionalArrayWithAnyofs': {
          'anyOf': [
            {
              'type': 'array',
              'items': {'type': 'string'},
            },
            {
              'type': 'array',
              'items': {'type': 'number'},
            },
            {
              'type': 'array',
              'items': {
                'type': 'object',
                'properties': {
                  'test': {'type': 'string'},
                },
              },
            },
          ],
        },
      },
      'required': ['nestedObject', 'nestedArray'],
    },
    formData: PresenceValue({'nestedObject': {}, 'nestedArray': []}),
  ),
  const Sample(
    title: 'Fallback (unknown schema)',
    category: SampleCategory.misc,
    jsonSchema: {'title': 'Fallback', 'description': 'A field with no JSON Schema "type".'},
    formData: PresenceValue(1234),
  ),
  const Sample(
    title: 'Union types',
    category: SampleCategory.combinators,
    jsonSchema: {
      'title': 'Union type lists',
      'type': 'object',
      'properties': {
        'plain': {
          'title': 'string or integer',
          'type': ['string', 'integer'],
        },
        'constrained': {
          'title': 'anyOf on top of the union',
          'type': ['string', 'integer'],
          'anyOf': [
            {'type': 'integer', 'minimum': 20},
            {'type': 'string', 'maxLength': 2},
          ],
        },
      },
    },
    formData: PresenceValue({'plain': 'asd'}),
  ),
  const Sample(
    title: 'Blank',
    category: SampleCategory.misc,
    jsonSchema: null,
    formData: PresenceValue({}),
  ),
  const Sample(
    title: 'Empty schema',
    category: SampleCategory.misc,
    jsonSchema: {},
  ),
];

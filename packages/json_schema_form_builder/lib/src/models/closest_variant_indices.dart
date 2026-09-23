import 'dart:math';

import 'package:form_foundation/form_foundation.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// Decides whether [formData] satisfies [schema]. Injected instead of calling
/// schema.validate directly so the caller controls the validation context
/// (root-document `$ref`s) and the failure policy (a schema the validator
/// cannot process counts as non-matching).
typedef Validator = Future<bool> Function(Schema schema, dynamic formData);

// Scoring weight constants — extracted for readability and ease of change
const int _scoreExactConst = 1000;
const int _scoreEnumMatch = 500;
const int _scoreTypeMatch = 100;
const int _scoreRequiredField = 25;
const int _scorePropertyKey = 10;
const int _scoreNestedDivisor = 4;
const int _maxRecursionDepth = 8;

/// The anyOf/oneOf alternatives of [options] matching [formData] best —
/// react-jsonschema-form's getClosestMatchingOption adapted to report
/// ambiguity instead of resolving it.
///
/// Contract: the returned set is EMPTY when no alternative passes
/// [validator] (unlike rjsf, which silently falls back to option 0), and
/// contains SEVERAL indices on an equal-score tie (e.g. an empty object
/// matches both `{}` and a property-only branch). The caller owns the
/// tie-break: the Variant widget takes the first index as the initial
/// dropdown selection and keeps the live selection itself
/// (JsonFieldState.matchedVariantIndices is a build-time snapshot).
///
/// Every alternative is validated and the valid ones are scored: const match
/// 1000, enum match 500, type match 100, each present required property 25,
/// each present declared property 10; nested objects recurse (depth-limited)
/// with the child score divided by 4.
Future<Set<int>> closestVariantIndices({
  required List<Schema?> options,
  required dynamic formData,
  required Validator validator,
}) async {
  int bestScore = -1;
  final Set<int> bestIndices = {};

  for (var i = 0; i < options.length; i++) {
    final option = options[i];
    if (option == null) continue;

    final valid = await validator(option, formData);
    if (!valid) continue;

    final score = _calculateScore(option, formData);

    if (score > bestScore) {
      bestScore = score;
      bestIndices
        ..clear()
        ..add(i);
    } else if (score == bestScore) {
      bestIndices.add(i);
    }
  }

  return bestIndices;
}

/// Computes a heuristic score of how well [schema] matches [formData].
///
/// [depth] is used to limit the recursion depth when analyzing
/// nested objects.
int _calculateScore(
  Schema schema,
  dynamic formData, {
  int depth = 0,
}) {
  int score = 0;

  // Type match
  final schemaType = schema.type;
  if (schemaType is String && _matchesType(schemaType, formData)) {
    score += _scoreTypeMatch;
  }

  // Exact match with const
  final constValue = schema.constValue;
  if (constValue != null && constValue == formData) {
    score += _scoreExactConst;
  }

  // Match with one of the enum values
  final enumValues = schema.enumValues;
  if (enumValues is List && deepIndexOf(enumValues, formData) != -1) {
    score += _scoreEnumMatch;
  }

  // Analysis of object properties
  if (schema is ObjectSchema && formData is Map<String, dynamic>) {
    final required = schema.required;
    if (required is List<String>) {
      for (final field in required) {
        if (formData.containsKey(field)) {
          score += _scoreRequiredField;
        }
      }
    }

    final properties = schema.properties;
    if (properties != null) {
      for (final key in properties.keys) {
        if (formData.containsKey(key)) {
          score += _scorePropertyKey;
        }
      }

      // Recursive analysis of nested objects with a depth limit
      if (depth < _maxRecursionDepth) {
        for (final entry in properties.entries) {
          final childValue = formData[entry.key];
          if (childValue != null) {
            score +=
                _calculateScore(
                  entry.value,
                  childValue,
                  depth: depth + 1,
                ) ~/
                _scoreNestedDivisor;
          }
        }
      }
    }
  }

  return max(score, 0);
}

bool _matchesType(
  String? schemaType,
  dynamic value,
) {
  switch (schemaType) {
    case 'string':
      return value is String;

    case 'number':
      return value is num;

    case 'integer':
      return value is int;

    case 'boolean':
      return value is bool;

    case 'array':
      return value is List;

    case 'object':
      return value is Map<String, dynamic>;

    case 'null':
      return value == null;

    default:
      return false;
  }
}

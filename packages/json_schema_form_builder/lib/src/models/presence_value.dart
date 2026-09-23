// Adapted from the Value<T> class of the drift package
// (https://github.com/simolus3/drift), Copyright (c) 2019 Simon Binder,
// MIT License — full notice in THIRD_PARTY_LICENSES at the package root.
// Changes: renamed to PresenceValue, deep collection equality, valueOrNull,
// an assert on reading an absent value, JSON-oriented documentation.

import 'package:flutter/foundation.dart';
import 'package:form_foundation/form_foundation.dart';

/// A presence-aware value container: distinguishes "the key is absent from
/// the document" ([PresenceValue.absent]) from "the key is present with the value
/// null" (`PresenceValue(null)`) — a distinction plain nullable types cannot
/// express and JSON editing depends on (removing a key vs writing an
/// explicit null are different edits).
///
/// Equality is deep: two Values wrapping equal collections are equal.
@immutable
class PresenceValue<T> {
  /// Create a (present) value by wrapping the [value] provided.
  const PresenceValue(T value) : _value = value, present = true;

  /// Create a value that is absent if [value] is `null` and present if it's
  /// not.
  ///
  /// The functionality is equivalent to the following:
  /// `x != null ? PresenceValue(x) : PresenceValue.absent()`.
  const PresenceValue.absentIfNull(T? value) : _value = value, present = value != null;

  /// Create an absent value: the key it stands for is not in the document.
  const PresenceValue.absent() : _value = null, present = false;

  /// Whether this [PresenceValue] carries a value (which may itself be null: an
  /// explicit JSON null is a present value).
  final bool present;

  final T? _value;

  /// The wrapped value; asserts when absent. Prefer [valueOrNull] unless
  /// presence was already checked.
  T get value {
    assert(present, 'PresenceValue.absent has no value');
    return _value as T;
  }

  /// The wrapped value, or null when absent — indistinguishable from a
  /// present null; check [present] where the distinction matters.
  T? get valueOrNull => present ? _value : null;

  @override
  String toString() => present ? 'PresenceValue($valueOrNull)' : 'PresenceValue.absent()';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is PresenceValue<dynamic> && present == other.present && deepEquals(_value, other._value));

  @override
  int get hashCode => Object.hash(present, deepHash(_value));
}

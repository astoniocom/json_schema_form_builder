import 'package:collection/collection.dart';

const DeepCollectionEquality _deepEquality = DeepCollectionEquality();

/// Deep structural equality of two JSON values: maps and lists are compared
/// by content, leaves by `==`.
///
/// Delegates to [DeepCollectionEquality]
/// so equal content matches regardless of the runtime generic type (a decoded
/// `List<dynamic>` equals a literal `List<int>`) and numbers compare by value
/// (`1 == 1.0`), matching JSON Schema equality of instances.
bool deepEquals(dynamic a, dynamic b) => _deepEquality.equals(a, b);

/// Deep structural hash of a JSON value, consistent with [deepEquals]
/// (a `hashCode` built with this pairs with an `==` built with that).
int deepHash(dynamic value) => _deepEquality.hash(value);

/// Index of the first element of [values] deeply equal ([deepEquals]) to
/// [target], or -1 when there is none. The deep-equality counterpart of
/// `List.indexOf`.
int deepIndexOf(
  List<dynamic> values,
  dynamic target,
) {
  for (var i = 0; i < values.length; i++) {
    if (deepEquals(values[i], target)) {
      return i;
    }
  }

  return -1;
}

import 'package:form_foundation/form_foundation.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import 'json_field_state.dart';

/// The domain-side context of state building: where the field lives inside
/// the JSON document (grown top-down by [child] as the pipeline descends
/// into object properties and array items) plus the root schema, so
/// document-rooted `$ref`s (`#/definitions/...`) and the
/// best-matching-alternative search can see the whole document.
class FieldResolveContext {
  /// Creates a resolve context; the root of a document is
  /// `FieldResolveContext(path: const [], rootSchema: ...)`.
  const FieldResolveContext({
    required this.path,
    required this.rootSchema,
    this.expandedRefs = const {},
  });

  /// Segments from the document root to this field (object keys and array
  /// indices as strings). Used to attribute validation errors to fields and
  /// to identify the field in error reports.
  ///
  /// Treated as immutable (the const constructor forbids an unmodifiable
  /// wrapper): derivations copy, holders must not mutate.
  final List<String> path;

  /// The schema of the WHOLE document (not of this field); null when editing
  /// schema-less JSON. Passed unchanged all the way down.
  final Schema? rootSchema;

  /// The raw `$ref` strings already expanded on the descent from the root to
  /// this field (grown by the registry's enrichment step via
  /// [withExpandedRef]). The registry's cycle guard collapses a valueless
  /// field whose `$ref` repeats an entry of this set instead of expanding it
  /// (a recursive schema would otherwise descend forever); see
  /// CycleFieldState.
  ///
  /// Same immutability contract as [path].
  final Set<String> expandedRefs;

  /// The context of the child field under [key] (a property name or a
  /// stringified array index).
  FieldResolveContext child(String key) => FieldResolveContext(
    path: [...path, key],
    rootSchema: rootSchema,
    expandedRefs: expandedRefs,
  );

  /// This context with [ref] recorded as expanded (see [expandedRefs]).
  FieldResolveContext withExpandedRef(String ref) => FieldResolveContext(
    path: path,
    rootSchema: rootSchema,
    expandedRefs: {...expandedRefs, ref},
  );

  @override
  String toString() => path.join('/');
}

/// [FieldResolveContext] plus presentation state: how deep inside the
/// currently opened dialog the field is, whether its title row is shown, and
/// the whole-form state for cross-field decisions. Widgets derive children
/// with [child], open a fresh dialog scope with [resetDisplay] and suppress
/// the title row with [withoutHeader].
class FieldDisplayContext extends FieldResolveContext {
  /// Creates a display context; widgets usually derive one via [child],
  /// [resetDisplay] or [withoutHeader] instead.
  const FieldDisplayContext({
    required super.path,
    required super.rootSchema,
    required this.dialogPath,
    required this.formState,
    required this.displayHeader,
    this.absentAllowed = true,
    super.expandedRefs,
  });

  /// The context of the form root: empty paths, header shown, root schema
  /// taken from [formState].
  FieldDisplayContext.root({
    required this.formState,
  }) : dialogPath = const [],
       displayHeader = true,
       absentAllowed = true,
       super(path: const [], rootSchema: formState.rootSchema);

  /// Path within the dialog. Used to create indentation in the field tree.
  final List<String> dialogPath;

  /// State of the whole form, making it possible to implement field visibility.
  final JsonFieldState<Schema> formState;

  /// Whether the editor renders its own title row. Suppressed (via
  /// [withoutHeader]) when the surrounding widget already shows the title,
  /// e.g. the Variant switcher above an alternative.
  final bool displayHeader;

  /// Whether an absent value is representable at this document position.
  /// True for object properties and the form root (clearing removes the
  /// key / the whole value); set to false (via [disallowAbsent]) by the
  /// array editor for its items — a list slot always holds a value, so the
  /// parent coerces an absent write back to the type's empty representation
  /// and controls whose only effect is "clear to absent" (the Null editor's
  /// reset button) would silently do nothing.
  ///
  /// Reset to true by [child] (an array item's own properties can be absent
  /// again); preserved by the same-position derivations ([resetDisplay],
  /// [withoutHeader], [withExpandedRef]) so the fact survives dialog hops.
  final bool absentAllowed;

  /// The single place deciding how an editor presents itself: framed inside
  /// an opened dialog, expanded at the form/dialog root, and without the
  /// title row when the header is suppressed (e.g. a variant alternative).
  EditorGroupView get editorGroupView {
    if (dialogPath.isNotEmpty) return EditorGroupView.framed;
    return displayHeader ? EditorGroupView.expanded : EditorGroupView.expandedWithoutTitle;
  }

  @override
  FieldDisplayContext child(String key) => FieldDisplayContext(
    formState: formState,
    path: [...path, key],
    dialogPath: [...dialogPath, key],
    rootSchema: rootSchema,
    expandedRefs: expandedRefs,
    displayHeader: true,
  );

  @override
  FieldDisplayContext withExpandedRef(String ref) => FieldDisplayContext(
    formState: formState,
    path: path,
    dialogPath: dialogPath,
    rootSchema: rootSchema,
    expandedRefs: {...expandedRefs, ref},
    displayHeader: displayHeader,
    absentAllowed: absentAllowed,
  );

  /// A fresh display scope at the same document position: [dialogPath] is
  /// cleared so the field renders as a dialog root. Called when an editor
  /// dialog opens (ArrayField, FieldEditorScreen, variant alternatives).
  FieldDisplayContext resetDisplay() => FieldDisplayContext(
    formState: formState,
    path: path,
    dialogPath: [],
    rootSchema: rootSchema,
    expandedRefs: expandedRefs,
    displayHeader: true,
    absentAllowed: absentAllowed,
  );

  /// This context with the editor's own title row suppressed (see
  /// [displayHeader]).
  FieldDisplayContext withoutHeader() => FieldDisplayContext(
    formState: formState,
    path: path,
    dialogPath: dialogPath,
    rootSchema: rootSchema,
    expandedRefs: expandedRefs,
    displayHeader: false,
    absentAllowed: absentAllowed,
  );

  /// This context with absent marked non-representable (see [absentAllowed]).
  FieldDisplayContext disallowAbsent() => FieldDisplayContext(
    formState: formState,
    path: path,
    dialogPath: dialogPath,
    rootSchema: rootSchema,
    expandedRefs: expandedRefs,
    displayHeader: displayHeader,
    absentAllowed: false,
  );
}

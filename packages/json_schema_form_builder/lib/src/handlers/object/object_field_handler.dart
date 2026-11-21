import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/json_form_localizations.dart';
import '../../models/field_build_request.dart';
import '../../models/field_context.dart';
import '../../models/json_field_handler.dart';
import '../../models/json_field_state.dart';
import '../../models/json_handler_registration.dart';
import '../../models/json_handler_registry.dart';
import '../../models/presence_value.dart';
import '../../models/schema_values.dart';
import '../../models/type_matching.dart';
import '../../utils/utils.dart';
import '../../widgets/field_with_variants.dart';
import 'object_field.dart';
import 'object_field_display_mode.dart';
import 'object_field_entry.dart';
import 'object_field_state.dart';
import 'property_schemas.dart';

/// The handler of object fields: builds ObjectFieldState (one child state
/// per rendered property) and renders an ObjectField.
class ObjectFieldHandler extends JsonFieldHandler<ObjectFieldState> {
  /// Creates the handler; see the fields for the knobs.
  const ObjectFieldHandler({
    required super.registryGetter,
    required this.displayMode,
    this.inline = true,
    this.validateOnChange = true,
    this.minInlineWidth = defaultMinInlineWidth,
    // An object emptied by user edits stays in the document as {} (rjsf-like)
    // instead of collapsing to absent, which would drop the property's key
    // from the parent (and the whole document at the form root). Configure
    // PresenceValue.absent() to get the collapsing behavior.
    this.emptyValue = const PresenceValue(<String, Object?>{}),
    this.requireExplicitAdditionalProperties = true,
  });

  /// Which properties get child states (see ObjectFieldDisplayMode).
  final ObjectFieldDisplayMode displayMode;

  /// Whether the object renders its rows in place when the width allows;
  /// false always renders the collapsed row opening the edit dialog.
  final bool inline;

  /// Whether edits inside the editor dialog are validated as they happen.
  final bool validateOnChange;

  /// Minimal width (logical px) at which an [inline] editor is still usable;
  /// in a narrower slot the field collapses into a compact editor (a button
  /// that opens the edit dialog) instead.
  final double minInlineWidth;

  /// What an object emptied by user edits writes: `{}` by default (rjsf-like,
  /// keeps the key in the parent), `PresenceValue.absent()` to collapse.
  final PresenceValue<dynamic> emptyValue;

  /// If true — the add-property button and the additional fields themselves
  /// are shown only with an explicit additionalProperties: true or a schema.
  /// If false — we follow the spec: a missing additionalProperties is treated as true.
  final bool requireExplicitAdditionalProperties;

  /// Merges the switched variant's map value into the current object instead
  /// of replacing value wholesale (see ObjectFieldState.applyVariantSwitch).
  @override
  void applyVariantSwitched({
    required int? oldIndex,
    required int newIndex,
    required ObjectFieldState fieldState,
    required void Function(JsonFieldState) onChanged,
  }) {
    final variants = fieldState.variants;
    if (variants == null || newIndex < 0 || newIndex >= variants.length) {
      assert(false, 'Invalid variant index $newIndex');
      return;
    }

    final oldState = oldIndex == null ? null : variants.elementAtOrNull(oldIndex);
    final newState = variants[newIndex];

    // A pinned alternative (const or single-element enum) writes its value
    // as is (base class logic), merge semantics do not apply.
    if (oldState is! ObjectFieldState || newState is! ObjectFieldState || schemaPinnedValue(newState.schema).present) {
      super.applyVariantSwitched(oldIndex: oldIndex, newIndex: newIndex, fieldState: fieldState, onChanged: onChanged);
      return;
    }

    final newRawValue = newState.valueOrNull;
    if (newRawValue != null && newRawValue is! Map<String, Object?>) {
      super.applyVariantSwitched(oldIndex: oldIndex, newIndex: newIndex, fieldState: fieldState, onChanged: onChanged);
      return;
    }

    final updatedState = fieldState.applyVariantSwitch(oldState: oldState, newState: newState);
    onChanged.call(updatedState);
  }

  /// Unlike the base implementation, reports an out-of-range variant index
  /// via FlutterError instead of relying on the debug-only assert inside
  /// JsonFieldState.applyVariantUpdate.
  @override
  void applyVariantUpdated({
    required int index,
    required JsonFieldState variantState,
    required ObjectFieldState fieldState,
    required FieldDisplayContext displayContext,
    required void Function(JsonFieldState) onChanged,
  }) {
    if (index < 0 || index >= (fieldState.variants?.length ?? 0)) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: RangeError('Invalid variant index $index'),
          stack: StackTrace.current,
          library: 'json_schema_form_builder',
          context: ErrorDescription('Path: ${displayContext.path}'),
        ),
      );
      return;
    }

    onChanged.call(fieldState.applyVariantUpdate(index, variantState, emptyValue));
  }

  @override
  Widget buildField({
    required BuildContext context,
    required ObjectFieldState fieldState,
    required FieldDisplayContext displayContext,
    void Function(JsonFieldState)? onChanged,
  }) {
    // A schema with its own anyOf/oneOf renders the object editor PLUS the
    // switcher — but only when the base schema itself accepts the object
    // type (declared or inferred, see typesAcceptedBy): then the branches
    // refine the base object (merge semantics, see applyVariantSwitched).
    //
    // A bare `{oneOf: [...]}` (no own type) renders only the switcher, like
    // scalars and arrays. There the handler — and thus the widget at this
    // position — is picked by the VALUE type; if the base editor rendered
    // too, a keystroke that changes the value's type (e.g. null -> {name})
    // would flip the widget from EditorGroup to ObjectField, remount the
    // switcher's subtree and kill the focus of the field being typed into
    // (a cycle field inside a oneOf branch of an array item reproduced it).
    //
    // Synthesized type branches are complete alternatives whose selected
    // branch renders the same editor the base would, so only the switcher
    // renders as well (see schemaHasOwnAlternatives).
    final schema = fieldState.schema;
    final refinesOwnObject = schemaHasOwnAlternatives(schema) && schema != null && typesAcceptedBy(schema).contains(JsonType.object);
    if (!refinesOwnObject && (fieldState.variants?.isNotEmpty ?? false)) {
      return buildFieldWithVariants(
        context: context,
        fieldState: fieldState,
        displayContext: displayContext,
        onChanged: onChanged,
        // Unreachable: buildFieldWithVariants only consults the content
        // builder when there are no variants.
        contentBuilder: (_) => const SizedBox.shrink(),
      );
    }

    return ObjectField(
      emptyValue: emptyValue,
      displayContext: displayContext,
      fieldState: fieldState,
      handlerRegistry: registry,
      onChanged: onChanged,
      requireExplicitAdditionalProperties: requireExplicitAdditionalProperties,
      inline: inline,
      minInlineWidth: minInlineWidth,
      validateOnChange: validateOnChange,
      child: buildVariant(context: context, fieldState: fieldState, displayContext: displayContext, onChanged: onChanged),
    );
  }

  @override
  Future<ObjectFieldState> buildState(FieldBuildRequest request) async {
    final schema = request.schema;
    final value = request.value;
    final errors = request.errors;
    final resolveContext = request.resolveContext;

    final ObjectSchema? objectSchema = schema is ObjectSchema ? schema : null;

    final rawValue = value.valueOrNull;
    final Map<String, dynamic> mapValue = rawValue is Map<String, dynamic> ? rawValue : {};
    final fieldOrder = resolveOrder(items: mapValue, schema: objectSchema);
    final schemaProperties = objectSchema?.properties ?? {};
    final requiredKeys = objectSchema?.required?.toSet() ?? {};

    final additionalPropertiesAllowed = resolveAdditionalPropertiesAllowed(objectSchema, treatUnspecifiedAsForbidden: requireExplicitAdditionalProperties);
    final fieldNamePatterns =
        objectSchema?.patternProperties?.map(
          (pattern, s) => MapEntry(RegExp(pattern), s),
        ) ??
        const {};

    final keysToProcess = fieldOrder.where((key) {
      final inUserData = mapValue.containsKey(key);
      final matchesPattern = fieldNamePatterns.keys.any((p) => p.hasMatch(key));
      final inSchema = schemaProperties.containsKey(key) || matchesPattern;
      final isRequired = requiredKeys.contains(key);
      return switch (displayMode) {
        ObjectFieldDisplayMode.all => true,
        ObjectFieldDisplayMode.userOnly => inUserData || !inSchema || isRequired,
        ObjectFieldDisplayMode.userAndRequired => inUserData || isRequired,
      };
    });

    final List<MapEntry<String, ObjectFieldEntry>> childEntries = [];
    for (final key in keysToProcess) {
      final matchesPattern = fieldNamePatterns.keys.any((p) => p.hasMatch(key));
      final isAdditional = !schemaProperties.containsKey(key) && !matchesPattern;
      if (isAdditional && !additionalPropertiesAllowed) continue;

      final fieldSchema = objectSchema != null ? computeSchemasForKey(objectSchema, key, fieldNamePatterns).firstOrNull : null;

      final fieldValue = mapValue.containsKey(key) ? PresenceValue(mapValue[key]) : const PresenceValue.absent();
      final errorsForField = errors
          ?.where((e) => e.path.firstOrNull == key)
          .map((e) => ValidationError(e.error, path: e.path.sublist(1), details: e.details))
          .toList(growable: false);

      final fieldState = await registry.buildState(
        FieldBuildRequest(
          value: fieldValue,
          // fieldSchema derives from the object schema, whose request always
          // carries a context, so `maybe` never sees a context-less schema.
          schemaSource: SchemaWithContext.maybe(fieldSchema, request.schemaResolveContext),
          errors: errorsForField,
          title: fieldSchema?.title ?? key,
          resolveContext: resolveContext.child(key),
          required: requiredKeys.contains(key),
          readOnly: request.fieldAnnotations?.readOnly ?? false,
        ),
      );
      if (fieldState == null) continue;

      childEntries.add(MapEntry(key, ObjectFieldEntry(state: fieldState, additional: isAdditional)));
    }

    final childrenMap = Map.fromEntries(childEntries);

    // Building state from JSON must not modify the input (Json -> State ->
    // Json is an identity), so the value is passed through unchanged. Do NOT
    // rebuild it from childrenMap: children are filtered by display policy
    // (additionalProperties, displayMode), and reconstruction silently dropped
    // the filtered keys (e.g. properties declared only in anyOf branches).
    // defaultValue/emptyValue are applied only on user interaction.

    // It is a mistake to use:
    // final PresenceValue<dynamic> newValue = value.present && rawValue is Map ? PresenceValue(mapChildrenToValue(childrenMap)) : value;
    // and then value: newValue.
    // There may be an object schema that has no 'properties' but only
    // anyOf. With that code childrenMap would be empty because of the early
    // exit on the isAdditional check. However, value.present would be true.
    // Consequently the value would be lost.

    return ObjectFieldState(
      schema: objectSchema,
      value: value,
      children: childrenMap,
      errors: errors?.where((e) => e.path.isEmpty).toList(growable: false),
      title: request.title,
      fieldAnnotations: request.fieldAnnotations,
      variants: request.variants,
      matchedVariantIndices: request.matchedVariantIndices,
      rootSchema: resolveContext.rootSchema,
      fieldNamePatterns: fieldNamePatterns,
    );
  }

  /// The default wiring of this handler for a type-based registry: claims
  /// the `object` schema type and the Map value type.
  static JsonHandlerRegistration registration(
    JsonHandlerRegistry Function() registryGetter, {
    ObjectFieldDisplayMode displayMode = ObjectFieldDisplayMode.all,
    bool inline = true,
  }) => JsonHandlerRegistration(
    stateType: ObjectFieldState,
    handler: ObjectFieldHandler(registryGetter: registryGetter, displayMode: displayMode, inline: inline),
    valueTypes: const [Map<String, dynamic>],
    schemaTypes: const [JsonType.object],
  );

  @override
  bool canEditValue(dynamic value) => dartTypeOfValue(value) == Map<String, dynamic>;

  @override
  PresenceValue<dynamic>? get canonicalEmptyValue => const PresenceValue(<String, Object?>{});

  @override
  String typeDisplayName(BuildContext context) => jsonFormLocalizationsOf(context).typeNameObject;

  @override
  bool matchesState(JsonFieldState state) => state is ObjectFieldState;
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:form_foundation/form_foundation.dart';

import '../../l10n/json_form_localizations.dart';
import '../../models/field_context.dart';
import '../../models/json_field_handler.dart';
import '../../models/json_field_state.dart';
import '../../models/json_handler_registry.dart';
import '../../models/presence_value.dart';
import '../../widgets/field_editor_screen.dart';
import 'object_entry_edit_dialog.dart';
import 'object_field_entry.dart';
import 'object_field_state.dart';
import 'property_schemas.dart';

typedef _MapNodeEditor = NodeEditor<String, JsonFieldState, JsonFieldState, ObjectFieldEntry, FieldResolveContext, JsonFieldHandler<JsonFieldState>>;

/// The editor of an object field: the property rows in a NodeEditor group,
/// an add-property button, and — when the available width is too small for
/// the inline form — a collapsed row opening the same editor in a dialog.
class ObjectField extends StatelessWidget {
  /// Creates an object field; null [onChanged] renders it read-only.
  const ObjectField({
    required this.fieldState,
    required this.handlerRegistry,
    required this.onChanged,
    required this.emptyValue,
    required this.displayContext,
    required this.requireExplicitAdditionalProperties,
    required this.inline,
    required this.minInlineWidth,
    required this.validateOnChange,
    this.child,
    super.key,
  });

  /// The state to render.
  final ObjectFieldState fieldState;

  /// The registry the child fields are rendered through.
  final JsonHandlerRegistry handlerRegistry;

  /// Receives the updated state; null disables editing.
  final ValueChanged<JsonFieldState>? onChanged;

  /// What removing the last property writes (see
  /// ObjectFieldHandler.emptyValue).
  final PresenceValue<dynamic> emptyValue;

  /// Where the field sits (dialog depth, header visibility).
  final FieldDisplayContext displayContext;

  /// See ObjectFieldHandler.requireExplicitAdditionalProperties.
  final bool requireExplicitAdditionalProperties;

  /// Forces the inline representation regardless of the available width
  /// (used inside the editor dialog, which is already the "expanded" place).
  final bool inline;

  /// See ObjectFieldHandler.minInlineWidth.
  final double minInlineWidth;

  /// Whether edits inside the editor dialog are validated as they happen.
  final bool validateOnChange;

  /// Extra content appended after the property rows (the variant switcher).
  final Widget? child;

  // fieldAnnotations.readOnly must be honored here: since buildField no
  // longer normalizes the callback for the content, a raw onChanged reaches
  // this widget even for read-only fields (same rule as ArrayField).
  bool get _isReadOnly => onChanged == null || (fieldState.fieldAnnotations?.readOnly ?? false);

  Future<(String, JsonFieldState)?> _openMapEntryEditDialog({required BuildContext context}) {
    final usedKeys = fieldState.children.keys.toSet();

    return showDialog<(String, JsonFieldState)>(
      context: context,
      builder: (context) => ObjectEntryEditDialog(
        handlerRegistry: handlerRegistry,
        forbiddenKeys: usedKeys,
        schema: fieldState.schema,
        displayContext: displayContext,
        requireExplicitAdditionalProperties: requireExplicitAdditionalProperties,
        fieldNamePatterns: fieldState.fieldNamePatterns,
      ),
    );
  }

  void _onChildrenChanged(Map<String, ObjectFieldEntry> newChildren) {
    onChanged?.call(fieldState.applyNewChildren(newChildren: newChildren, emptyValue: emptyValue));
  }

  Future<ObjectFieldState?> _openMapEditDialog({
    required BuildContext context,
    required String title,
  }) {
    return showDialog<ObjectFieldState>(
      context: context,
      builder: (context) {
        return FieldEditorScreen(
          initState: fieldState,
          registry: handlerRegistry,
          validateOnChange: validateOnChange,
          displayContext: displayContext,
          fieldTitle: title,
        );
      },
    );
  }

  Map<String, ObjectFieldEntry> _visibleEntries({required bool additionalPropertiesAllowed}) {
    if (fieldState.schema == null) return fieldState.children;

    final keyMatchesPatterns = fieldState.fieldNamePatterns.keys;

    return {
      for (final e in fieldState.children.entries.where((mapEntry) {
        if (!mapEntry.value.additional || additionalPropertiesAllowed) {
          return true;
        }

        if (keyMatchesPatterns.isNotEmpty) {
          final matchesPattern = keyMatchesPatterns.any((p) => p.hasMatch(mapEntry.key));
          if (matchesPattern) return true;
        }
        return false;
      }))
        e.key: e.value,
    };
  }

  Widget _buildInlineField(BuildContext context) {
    final additionalPropertiesAllowed = resolveAdditionalPropertiesAllowed(fieldState.schema, treatUnspecifiedAsForbidden: requireExplicitAdditionalProperties);

    final rawPatternProperties = fieldState.schema?.patternProperties;
    final patternPropertiesAllowed = rawPatternProperties != null && rawPatternProperties.isNotEmpty;

    final onAdd = !_isReadOnly && (additionalPropertiesAllowed || patternPropertiesAllowed)
        ? () async {
            final result = await _openMapEntryEditDialog(context: context);
            if (result == null) return;
            final (key, entryState) = result;

            final Map<String, ObjectFieldEntry> newChildren = {
              ...fieldState.children,
              key: ObjectFieldEntry(state: entryState, additional: true),
            };

            _onChildrenChanged(newChildren);
          }
        : null;

    return _MapNodeEditor(
      onChanged: _isReadOnly
          ? null
          : (key, handler, newValue) {
              var newValueLoc = newValue;
              if (!newValueLoc.hasValue && (fieldState.children[key]?.additional ?? false)) {
                // An additional property's row exists only while its key is
                // in the JSON, so accepting a "no value" write would silently
                // delete the whole property, typed-in key included. Clearing
                // must not act as removal (that is what the remove button is
                // for): the cleared state gets its type's empty
                // representation instead. Types with none (number etc.) drop
                // the write and keep the previous document value -- the
                // widget holds the empty text locally and canonicalizes it
                // back on blur.
                final typedEmptyValue = handler.canonicalEmptyValue;
                if (typedEmptyValue == null) return;
                newValueLoc = newValueLoc.copyWith(value: typedEmptyValue);
              }

              final newMapState = fieldState.applyChildValueChange(
                key: key,
                newValue: newValueLoc,
                emptyValue: emptyValue,
              );

              onChanged?.call(newMapState);
            },
      handlerRegistry: handlerRegistry,
      errors: fieldState.errors?.map((e) => e.toErrorString()).toList(growable: false),
      addButton: onAdd != null ? IconButton(onPressed: onAdd, icon: const Icon(Icons.add)) : null,
      displayContextForField: (key, _) => displayContext.child(key),
      fieldStates: _visibleEntries(additionalPropertiesAllowed: additionalPropertiesAllowed),
      testCanRemoveEntry: (mapEntry) => mapEntry.value.additional,
      onRemove: _isReadOnly
          ? null
          : (mapEntry) {
              _onChildrenChanged(Map.of(fieldState.children)..remove(mapEntry.key));
            },
      title: fieldState.title,
      helpText: fieldState.fieldAnnotations?.description,
      view: displayContext.editorGroupView,
      child: child,
    );
  }

  Widget _buildCompactEditor(BuildContext context) {
    // Unlike the inline editor (where a missing title simply omits the title
    // row), the compact editor's collapsed field needs a non-empty label,
    // hence the fallback chain.
    final l10n = jsonFormLocalizationsOf(context);
    final title = fieldState.title ?? displayContext.path.lastOrNull ?? l10n.objectFallbackTitle;
    final errors = [
      if (fieldState.childrenHasErrors) l10n.childrenHaveErrorsLabel,
      ...?fieldState.errors?.map((e) => e.toErrorString()),
    ];

    return CollapsedValueField(
      labelText: title,
      isRequired: fieldState.fieldAnnotations?.required ?? false,
      errorText: errors.isNotEmpty ? errors.join('\n') : null,
      helperText: fieldState.fieldAnnotations?.description,
      value: fieldState.valueOrNull,
      valueVerboseText: fieldState.valueOrNull is Map ? jsonEncode(fieldState.valueOrNull) : null,
      onEdit: _isReadOnly
          ? null
          : () async {
              final result = await _openMapEditDialog(context: context, title: title);
              if (result == null) return;
              onChanged?.call(result);
            },
    );
  }

  @override
  Widget build(BuildContext context) {
    // dialogPath (not path) decides inline vs dialog rendering: inside an
    // opened editor dialog the context is resetDisplay()-ed, so the object at
    // the dialog root must render inline instead of yet another compact
    // editor (same rule as ArrayField).
    if (displayContext.dialogPath.isEmpty) return _buildInlineField(context);
    if (!inline) return _buildCompactEditor(context);

    // Even when configured inline, a nested editor needs comfortable width:
    // in a cramped slot (deep nesting on a narrow screen) it collapses into
    // the compact variant (a button that opens the edit dialog).
    return WidthThresholdBuilder(
      minWidth: minInlineWidth,
      wideBuilder: _buildInlineField,
      narrowBuilder: _buildCompactEditor,
    );
  }
}

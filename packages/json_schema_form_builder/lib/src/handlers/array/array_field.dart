import 'dart:convert';

import 'package:form_foundation/form_foundation.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/json_form_localizations.dart';
import '../../models/field_build_request.dart';
import '../../models/field_context.dart';
import '../../models/json_field_handler.dart';
import '../../models/json_field_state.dart';
import '../../models/json_handler_registry.dart';
import '../../models/presence_value.dart';
import '../../models/schema_validation_mode.dart';
import '../../widgets/field_editor_screen.dart';
import 'array_field_state.dart';
import 'array_item_add_dialog.dart';
import 'enum_array_field.dart';

typedef _NewItemOption = ({
  JsonFieldHandler<JsonFieldState>? handler,
  Schema? itemSchema,
});

/// The editor of an array field: the element rows in a ListEditor group
/// (removable, drag-reorderable), an add-item button (with a type/schema
/// menu when several apply), an enum multi-select for unique select-like
/// items, and — when the available width is too small for the inline form —
/// a collapsed row opening the same editor in a dialog.
class ArrayField extends StatelessWidget {
  /// Creates an array field; null [onChanged] renders it read-only.
  const ArrayField({
    required this.emptyValue,
    required this.registry,
    required this.fieldState,
    required this.inline,
    required this.minInlineWidth,
    required this.displayContext,
    required this.onChanged,
    required this.validateOnChange,
    this.child,
    super.key,
  });

  /// What removing the last element writes (see ArrayFieldHandler.emptyValue).
  final PresenceValue<dynamic> emptyValue;

  /// The registry the element fields are rendered through.
  final JsonHandlerRegistry registry;

  /// The state to render.
  final ArrayFieldState fieldState;

  /// Forces the inline representation regardless of the available width
  /// (used inside the editor dialog, which is already the "expanded" place).
  final bool inline;

  /// See ArrayFieldHandler.minInlineWidth.
  final double minInlineWidth;

  /// Where the field sits (dialog depth, header visibility).
  final FieldDisplayContext displayContext;

  /// Receives the updated state; null disables editing.
  final void Function(JsonFieldState)? onChanged;

  /// Whether edits inside the editor dialog are validated as they happen.
  final bool validateOnChange;

  /// Extra content appended after the element rows (the variant switcher).
  final Widget? child;

  /// Opens the full-array editor dialog; resolves with the edited state on
  /// OK, null on cancel.
  @protected
  Future<ArrayFieldState?> openListEditDialog({
    required BuildContext context,
    required ArrayFieldState fieldState,
    required FieldDisplayContext displayContext,
  }) {
    final title = displayContext.path.lastOrNull ?? fieldState.schema?.title ?? jsonFormLocalizationsOf(context).listFallbackTitle;

    return showDialog(
      context: context,
      builder: (context) {
        return FieldEditorScreen(
          fieldTitle: title,
          initState: fieldState,
          registry: registry,
          validateOnChange: validateOnChange,
          displayContext: displayContext,
        );
      },
    );
  }

  /// The new-item state carrying its type's canonical empty value, when that
  /// value satisfies the item schema under the registry's validation mode;
  /// null when the type has no canonical empty value or the schema rejects
  /// it (the caller falls back to the entry dialog).
  Future<JsonFieldState?> _emptyStateIfValid(JsonFieldState newFieldState, Schema? itemSchema, Schema? rootSchema) async {
    final typedEmptyValue = registry.handlerForField(newFieldState).canonicalEmptyValue;
    if (typedEmptyValue == null) return null;

    final candidate = newFieldState.copyWith(value: typedEmptyValue);
    final errors = await registry.validateValue(
      itemSchema: itemSchema,
      rootSchema: rootSchema,
      value: candidate.valueOrNull,
    );
    final validated = candidate.applyErrors(errors);
    return validated.isSubmittable(registry.validationMode) ? validated : null;
  }

  PresenceValue<dynamic> _childrenToValue(List<JsonListFieldEntry> children) {
    // final value = children.where((child) => child.state.hasValue).map((child) => child.state.value).toList(growable: false);
    // Removed where((child) => child.state.hasValue), because otherwise a row disappears when its value is not filled in
    final value = children.map((child) => child.state.valueOrNull).toList(growable: false);
    return value.isEmpty ? emptyValue : PresenceValue(value);
  }

  ArrayFieldState _buildState(ArrayFieldState curState, List<JsonListFieldEntry> children) {
    return curState.copyWith(
      value: _childrenToValue(children),
      children: children,
    );
  }

  Widget _buildInlineField({
    required BuildContext context,
    required ArrayFieldState fieldState,
    required FieldDisplayContext displayContext,
    void Function(JsonFieldState)? onChanged,
  }) {
    final isReadOnly = fieldState.fieldAnnotations?.readOnly ?? false;

    Widget? addButton;
    if (onChanged != null && !isReadOnly) {
      final positionalItemSchemasForNew = fieldState.positionalItemSchemasForNew;
      final additionalItemsSchemaForNew = fieldState.additionalItemsSchemaForNew;
      Schema? itemsSchema;
      if (positionalItemSchemasForNew.length > fieldState.children.length) {
        itemsSchema = positionalItemSchemasForNew[fieldState.children.length];
      } else if (additionalItemsSchemaForNew != null) {
        itemsSchema = additionalItemsSchemaForNew;
      }

      final List<_NewItemOption> newItemOptions = [];
      if (itemsSchema != null) {
        final handlersForSchema = registry.handlersForSchema(
          schema: itemsSchema,
          resolveContext: displayContext.child(fieldState.children.length.toString()),
        );
        newItemOptions.addAll(handlersForSchema.map((handler) => (handler: handler, itemSchema: itemsSchema)));

        if (handlersForSchema.isEmpty) {
          newItemOptions.add((handler: null, itemSchema: itemsSchema));
        }
      }

      // No item schema at all: the user may add a value of any type.
      if (newItemOptions.isEmpty) {
        final pickable = registry.pickableHandlers(resolveContext: displayContext.child(fieldState.children.length.toString()));
        newItemOptions.addAll(pickable.map((handler) => (handler: handler, itemSchema: itemsSchema)));
      }

      final typesToAdd = newItemOptions
          .map((option) => NewItemOption<_NewItemOption>(data: option, title: option.handler?.typeDisplayName(context) ?? '?'))
          .toList(growable: false);

      addButton = AddButton<_NewItemOption>(
        typesToAdd: typesToAdd,
        onAdd: !isReadOnly
            ? (option) async {
                final valueSchema = option.itemSchema;
                final childDisplayContext = displayContext.child(fieldState.children.length.toString()).disallowAbsent();
                final newFieldState = await registry.withValidationContext(
                  itemSchema: valueSchema,
                  rootSchema: fieldState.rootSchema,
                  // buildStateForNewField: adding an item extends the JSON
                  // document, so the item schema's `const`/`default` seeds
                  // the value. The unknown fallback means the raw schema
                  // admitted no handler before resolution (e.g. a bare $ref):
                  // a null handler lets the registry re-select from the
                  // resolved schema, so the dialog gets an editable field.
                  body: (validationContext) => registry.buildStateForNewField(
                    stateBuilder: option.handler,
                    request: FieldBuildRequest(
                      value: const PresenceValue.absent(),
                      schemaSource: SchemaWithContext.maybe(valueSchema, validationContext),
                      title: valueSchema?.title,
                      errors: const [],
                      resolveContext: childDisplayContext,
                    ),
                  ),
                );

                // When the schema prescribes a value (const/default/property
                // defaults seeded by buildStateForNewField), the item is
                // added as is. A type whose canonical empty representation
                // ('', [], {}, the explicit null of the Null editor)
                // satisfies the item schema is appended immediately too and
                // edited in place. Otherwise — no canonical empty value
                // (number, bool) or an empty value the schema rejects (e.g.
                // minLength) — the user enters the value in a dialog first,
                // so an invalid or bare-null item is never appended silently.
                JsonFieldState? stateToAdd = newFieldState;
                if (!newFieldState.hasValue) {
                  stateToAdd = await _emptyStateIfValid(newFieldState, valueSchema, fieldState.rootSchema);

                  if (stateToAdd == null) {
                    if (!context.mounted) return;
                    stateToAdd = await showDialog<JsonFieldState>(
                      context: context,
                      builder: (context) => ArrayItemAddDialog(
                        initialState: newFieldState,
                        handlerRegistry: registry,
                        itemSchema: valueSchema,
                        rootSchema: fieldState.rootSchema,
                        displayContext: childDisplayContext.resetDisplay(),
                      ),
                    );
                    if (stateToAdd == null) return;
                  }
                }

                onChanged.call(
                  _buildState(fieldState, [
                    ...fieldState.children,
                    JsonListFieldEntry(state: stateToAdd, additional: true),
                  ]),
                );
              }
            : null,
      );
    }

    return ListEditor<JsonFieldState, dynamic, JsonFieldHandler<JsonFieldState>>(
      // disallowAbsent: a list slot always holds a value (see the onChanged
      // coercion below), so item editors must not offer clear-to-absent
      // controls that would silently do nothing.
      displayContextForField: (index, fieldState) => displayContext.child(index.toString()).disallowAbsent(),
      children: fieldState.children.map((e) => e.state).toList(growable: false),
      onChanged: onChanged != null && !isReadOnly
          ? (index, newValue) {
              var newValueLoc = newValue;
              if (!newValueLoc.hasValue) {
                // An array item cannot be absent: serializing an item state
                // with no value degrades it to null -- a type lie that fails
                // validation against the item schema (e.g. an object emptied
                // by clearing its last variant field). Clearing must keep
                // the item: the state gets its type's empty representation
                // instead, and types with none (number etc.) drop the write,
                // keeping the previous document value -- the widget holds
                // the empty input locally and canonicalizes it back on blur.
                final typedEmptyValue = registry.handlerForField(newValueLoc).canonicalEmptyValue;
                if (typedEmptyValue == null) return;
                newValueLoc = newValueLoc.copyWith(value: typedEmptyValue);
              }

              final childrenCopy = fieldState.children.toList();
              childrenCopy[index] = JsonListFieldEntry(
                state: newValueLoc,
                additional: fieldState.children[index].additional,
              );
              onChanged(_buildState(fieldState, childrenCopy));
            }
          : null,
      onRemoved: onChanged != null && !isReadOnly
          ? (index) {
              final valueCopy = fieldState.children.toList();
              valueCopy.removeAt(index);
              onChanged(_buildState(fieldState, valueCopy));
            }
          : null,
      onReorder: onChanged != null && !isReadOnly
          ? (oldIndex, newIndex) {
              final childrenCopy = fieldState.children.toList();
              final item = childrenCopy.removeAt(oldIndex);
              childrenCopy.insert(newIndex, item);
              onChanged(_buildState(fieldState, childrenCopy));
            }
          : null,
      handlerRegistry: registry,
      addButton: addButton,
      errors: fieldState.errors?.map((e) => e.toErrorString()),
      title: fieldState.title,
      helpText: fieldState.fieldAnnotations?.description,
      view: displayContext.editorGroupView,
      child: child,
    );
  }

  Widget _buildCompactEditor(BuildContext context) {
    final isReadOnly = fieldState.fieldAnnotations?.readOnly ?? false;
    final l10n = jsonFormLocalizationsOf(context);
    final errors = [
      if (fieldState.childrenHasErrors) l10n.childrenHaveErrorsLabel,
      ...?fieldState.errors?.map((e) => e.toErrorString()),
    ];

    final rawValue = fieldState.valueOrNull;
    final valueLoc = rawValue is List ? rawValue : [];

    return CollapsedValueField(
      labelText: fieldState.title ?? displayContext.path.lastOrNull ?? l10n.listFallbackTitle,
      errorText: errors.isNotEmpty ? errors.join('\n') : null,
      helperText: fieldState.fieldAnnotations?.description,
      value: fieldState.valueOrNull,
      valueVerboseText: valueLoc.isNotEmpty ? '${l10n.itemsSummary(valueLoc.length)}: ${jsonEncode(valueLoc)}' : null,
      onEdit: onChanged != null && !isReadOnly
          ? () async {
              final result = await openListEditDialog(context: context, fieldState: fieldState, displayContext: displayContext.resetDisplay());
              if (result == null) return;
              onChanged?.call(result);
            }
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isReadOnly = fieldState.fieldAnnotations?.readOnly ?? false;
    if (fieldState.isEnum) {
      return EnumArrayField(
        title: fieldState.title,
        helpText: fieldState.fieldAnnotations?.description,
        error: fieldState.errors?.map((e) => e.toErrorString()).join('\n'),
        fieldState: fieldState,
        displayContext: displayContext,
        handlerRegistry: registry,
        onChanged: onChanged != null && !isReadOnly ? (newChildren) => onChanged?.call(_buildState(fieldState, newChildren)) : null,
        readOnly: isReadOnly,
      );
    }

    // At the form root or a dialog root (dialogPath is empty) the editor is
    // always inline: a compact editor there would collapse the whole form (or
    // chain dialogs endlessly, since the dialog resets the display context).
    if (displayContext.dialogPath.isEmpty) {
      return _buildInlineField(context: context, fieldState: fieldState, displayContext: displayContext, onChanged: onChanged);
    }
    if (!inline) return _buildCompactEditor(context);

    // Even when configured inline, a nested editor needs comfortable width:
    // in a cramped slot (deep nesting on a narrow screen) it collapses into
    // the compact variant (a button that opens the edit dialog).
    return WidthThresholdBuilder(
      minWidth: minInlineWidth,
      wideBuilder: (context) => _buildInlineField(context: context, fieldState: fieldState, displayContext: displayContext, onChanged: onChanged),
      narrowBuilder: _buildCompactEditor,
    );
  }
}

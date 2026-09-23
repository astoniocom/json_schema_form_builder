import 'field_handler.dart';

/// The minimal registry contract the form widgets depend on: map a field
/// state to the handler that renders it. This is the only registry operation
/// the widgets of this package (NodeEditor, ListEditor) perform.
///
/// The contract deliberately prescribes no storage or lookup strategy: an
/// implementation may dispatch by the state's runtimeType (see
/// TypeBasedJsonHandlerRegistry in json_schema_form_builder), by the field's
/// position in the document, or by delegating to another registry. The
/// lookup must be total: every state gets some handler (a fallback for
/// unknown states is the implementation's concern).
abstract class FieldHandlerRegistry<FS, E, HD extends FieldHandler<FS, Object?, E>> {
  /// Const constructor for subclasses.
  const FieldHandlerRegistry();

  /// The handler that renders [field].
  HD handlerForField(FS field);
}

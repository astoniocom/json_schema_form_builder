# form_foundation example

A contact form composed by hand from the package's primitives. The point of
`form_foundation` is that it carries no schema logic: the app owns the
values, the validation, and the layout, and the package supplies the
building blocks.

Everything specific to the integration lives in `lib/main.dart`:

1. Typed leaf fields (`StringField`, `IntField`, `DoubleField`, `BoolField`,
   `StringDateField`) bound to plain Dart values via `onChanged`.
2. A hand-rolled collection editor: `EditorGroup` draws the frame,
   `RemovableRow` adds per-row delete buttons, `AddButton` appends items.
3. Form-level messages in an `ErrorsPanel`; a result dialog in a
   `FormDialog`.
4. One `FormTheme` at the top configures the spacing of every widget below.

For a schema-driven form generator built on these blocks see the
`json_schema_form_builder` package in this repository.

```sh
flutter run
```

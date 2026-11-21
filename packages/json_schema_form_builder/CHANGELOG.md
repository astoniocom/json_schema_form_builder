## 0.1.1

* Invalid JSON in `JsonEditor` is reported with the localized sentence
  only. The parser's English `FormatException` text is no longer appended.
* `JsonEditor.invalidJsonMessage` overrides that sentence. It receives the
  `FormatException`; when the callback is null, the localized sentence is
  used. The shown text updates when the built message changes.

## 0.1.0

Initial release.

* `JsonSchemaForm`: a live-validated form generated from a JSON Schema, with
  `validateOnChange` or on-demand `validate()`.
* Typed editors for all JSON types, driven by an extensible handler registry
  (`TypeBasedJsonHandlerRegistry`); custom handlers can replace or extend the
  standard set.
* Schema support: document-local `$ref` (including recursive schemas with a
  lazy cycle guard), `allOf` merging, `anyOf`/`oneOf` variants with closest-
  match selection, union types, `if`/`then`/`else`,
  `dependencies`/`dependentRequired`/`dependentSchemas`, `const`, `enum`,
  defaults (also behind `$ref`/`allOf`), draft-07 tuple normalization for
  validation.
* Validation modes (`SchemaValidationMode`): `none`, `lenient`, `strict`.
* Raw JSON editing: `JsonEditor` with lightweight syntax highlighting
  (`JsonHighlightingController`).
* Localization: English, Polish, Russian (`JsonFormLocalizations`).

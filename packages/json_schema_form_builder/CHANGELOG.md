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

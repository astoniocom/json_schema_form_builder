# json_schema_form_builder example

The minimal integration: one JSON Schema, a live-validated form generated
from it, and a Submit button gated by the validation result.

Everything specific to the integration lives in `lib/main.dart`:

1. Parse the schema once: `Schema.fromMap({...})`.
2. Drop a `JsonSchemaForm(schema: ..., onChanged: ...)` into the tree; the
   `onChanged` state carries the edited value (`state.value`) and the
   validation verdict (`state.isValid`).
3. Register `JsonFormLocalizations.localizationsDelegates` in the app.

For a full-featured showcase (schema editing, validation modes, theming,
custom file picker) see the `demo/` app next to this one.

```sh
flutter run
```

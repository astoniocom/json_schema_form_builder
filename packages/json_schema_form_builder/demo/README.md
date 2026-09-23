# demo

Full-featured demo of the [json_schema_form_builder](../) package: a sample
gallery (drawer) with a live form beside editable Schema/Json tabs with JSON
syntax highlighting, instant or on-demand validation, light and dark themes.

The app is built for the web and linked from the package description for
online testing. Every sample has a shareable URL (e.g. `/#/arrays`).

## Running locally

```sh
flutter run
```

## Building the web release

```sh
flutter build web
```

When hosting under a sub-path, pass `--base-href /sub-path/`.

## Attribution

Part of the sample schemas in `lib/sample_db.dart` is taken or adapted from
the [react-jsonschema-form playground](https://rjsf-team.github.io/react-jsonschema-form/)
([rjsf-team/react-jsonschema-form](https://github.com/rjsf-team/react-jsonschema-form),
Apache-2.0) so the two libraries can be compared on the same schemas.

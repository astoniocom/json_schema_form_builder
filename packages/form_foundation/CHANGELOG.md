## 0.1.0

Initial release.

* Typed field widgets: `StringField`, `IntField`, `DoubleField`, `BoolField`,
  `StringDateField`, `StringTimeField`, `StringDateTimeField`,
  `StringDataUrlField` — controlled components bound to plain values via
  `onChanged`, with labels, helper/error texts, required marking, and
  optional example dropdowns.
* Container building blocks: `EditorGroup` (framed/expanded group),
  `NodeEditor` and `ListEditor` (handler-driven object/array editors with
  removal and drag-and-drop reordering), `RemovableRow`, `AddButton`,
  `CollapsedValueField`, `ErrorsPanel`, `FormDialog`,
  `WidthThresholdBuilder`.
* Theming through `FormTheme`/`FormThemeData` (field padding, errors
  padding, group border, code text style), modeled after Material component
  themes.
* Schema-agnostic handler contracts (`FieldHandler`,
  `FieldHandlerRegistry`, `NodeState`) for form generators to build on.
* Utilities: RFC 2397 data URL parsing/encoding (`DataUrl`), deep
  collection equality helpers.

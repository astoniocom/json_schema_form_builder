import 'package:material_ui/material_ui.dart';

/// Visual configuration for form_foundation widgets.
///
/// Modeled after Material component themes (e.g. CardThemeData): an immutable
/// data object distributed down the tree by [FormTheme] and read by
/// the field widgets via [FormTheme.of]. Every property has a default,
/// so widgets work without a theme in the tree.
@immutable
class FormThemeData {
  /// Creates form theme data; every property has a usable default.
  const FormThemeData({
    this.fieldPadding = const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    this.errorsPadding = const EdgeInsets.all(8),
    this.groupBorder,
    this.codeTextStyle,
  });

  /// Outer padding of every leaf field widget (string, numbers, bool,
  /// date/time, collapsed object) and of group frames, e.g. horizontal
  /// indents: `EdgeInsets.symmetric(horizontal: 8)`.
  ///
  /// Groups apply it to their own frame as well, so on multi-level forms
  /// every nesting level adds one more indent step.
  final EdgeInsetsGeometry fieldPadding;

  /// Inner padding of the validation errors block (ErrorsPanel).
  final EdgeInsetsGeometry errorsPadding;

  /// The frame of group editors (EditorGroup).
  ///
  /// When null (the default), the group inherits the app's
  /// `inputDecorationTheme.border` and, when that is not configured either,
  /// falls back to [OutlineInputBorder]: a group must always keep a visible
  /// frame — the Material default (an underline) would dissolve the grouping.
  /// Set this to style group frames independently of the text fields.
  final InputBorder? groupBorder;

  /// Text style of code editors (e.g. the raw JSON editor).
  ///
  /// When null (the default), widgets fall back to `bodySmall` with the
  /// generic `monospace` family. That family does not resolve on macOS/web
  /// (the text silently falls back to a proportional font), so apps bundling
  /// a monospace font should point this style at it.
  final TextStyle? codeTextStyle;

  /// A copy with the given properties replaced.
  FormThemeData copyWith({
    EdgeInsetsGeometry? fieldPadding,
    EdgeInsetsGeometry? errorsPadding,
    InputBorder? groupBorder,
    TextStyle? codeTextStyle,
  }) {
    return FormThemeData(
      fieldPadding: fieldPadding ?? this.fieldPadding,
      errorsPadding: errorsPadding ?? this.errorsPadding,
      groupBorder: groupBorder ?? this.groupBorder,
      codeTextStyle: codeTextStyle ?? this.codeTextStyle,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FormThemeData &&
        other.fieldPadding == fieldPadding &&
        other.errorsPadding == errorsPadding &&
        other.groupBorder == groupBorder &&
        other.codeTextStyle == codeTextStyle;
  }

  @override
  int get hashCode => Object.hash(fieldPadding, errorsPadding, groupBorder, codeTextStyle);
}

/// Applies [FormThemeData] to the descendant form widgets, analogous
/// to Material component theme widgets (CardTheme, ListTileTheme):
///
/// ```dart
/// FormTheme(
///   data: FormThemeData(
///     fieldPadding: EdgeInsets.symmetric(horizontal: 8),
///   ),
///   child: FieldEditorScreen(...),
/// )
/// ```
class FormTheme extends InheritedTheme {
  /// Applies [data] to the widgets below [child].
  const FormTheme({
    required this.data,
    required super.child,
    super.key,
  });

  /// The configuration distributed to the descendant form widgets.
  final FormThemeData data;

  static const FormThemeData _defaults = FormThemeData();

  /// The data of the closest [FormTheme] above [context]; falls back
  /// to the defaults, so callers can read it unconditionally.
  static FormThemeData of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<FormTheme>()?.data ?? _defaults;
  }

  /// The effective [FormThemeData.fieldPadding] at [context].
  static EdgeInsetsGeometry fieldPaddingOf(BuildContext context) {
    return of(context).fieldPadding.resolve(Directionality.of(context));
  }

  /// The effective group frame border at [context]:
  /// [FormThemeData.groupBorder], else the border of the app's
  /// `inputDecorationTheme`, else [OutlineInputBorder] — a group frame must
  /// never dissolve (the Material default, an underline, is no frame).
  ///
  /// The single resolution point for every widget drawing a group-style
  /// frame, so custom widgets match EditorGroup by construction.
  static InputBorder groupBorderOf(BuildContext context) {
    return of(context).groupBorder ?? Theme.of(context).inputDecorationTheme.border ?? const OutlineInputBorder();
  }

  /// The effective code editor text style at [context]:
  /// [FormThemeData.codeTextStyle], else `bodySmall` with the generic
  /// `monospace` family (see the [FormThemeData.codeTextStyle] caveat about
  /// macOS/web).
  static TextStyle? codeTextStyleOf(BuildContext context) {
    return of(context).codeTextStyle ?? Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace');
  }

  /// The contentPadding for the childless [InputDecorator] that draws a group
  /// frame: it positions only the floating label (the content is stacked on
  /// top of the decorator with no inset), so the horizontal component of the
  /// app's `inputDecorationTheme.contentPadding` must be re-applied here
  /// explicitly; without a themed value the label gets the default Material 3
  /// outline start inset (12).
  static EdgeInsetsDirectional groupLabelPaddingOf(BuildContext context) {
    final themePadding = Theme.of(context).inputDecorationTheme.contentPadding;
    if (themePadding == null) return const EdgeInsetsDirectional.only(start: 12);
    final direction = Directionality.of(context);
    final resolved = themePadding.resolve(direction);
    final start = switch (direction) {
      TextDirection.ltr => resolved.left,
      TextDirection.rtl => resolved.right,
    };
    return EdgeInsetsDirectional.only(start: start);
  }

  @override
  bool updateShouldNotify(covariant FormTheme oldWidget) => data != oldWidget.data;

  /// InheritedTheme contract: re-applies this theme when a subtree is moved
  /// to another context (e.g. an overlay), same as Material themes do.
  @override
  Widget wrap(BuildContext context, Widget child) => FormTheme(data: data, child: child);
}

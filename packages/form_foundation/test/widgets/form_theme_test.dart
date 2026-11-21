import 'package:flutter_test/flutter_test.dart';
import 'package:form_foundation/form_foundation.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Widget buildSubject({FormThemeData? theme}) {
    Widget child = const Scaffold(
      body: StringField(value: 'text', title: 'Title'),
    );
    if (theme != null) {
      child = FormTheme(data: theme, child: child);
    }
    return MaterialApp(home: child);
  }

  // The padding applied by the field itself: the direct Padding ancestor of
  // the field's root (CompositedTransformTarget).
  Padding fieldPaddingOf(WidgetTester tester) {
    return tester.widget<Padding>(
      find
          .ancestor(
            of: find.byType(CompositedTransformTarget),
            matching: find.byType(Padding),
          )
          .first,
    );
  }

  group('FormTheme', () {
    testWidgets('without a theme fields use the default padding', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(fieldPaddingOf(tester).padding, const FormThemeData().fieldPadding);
      expect(const FormThemeData().fieldPadding, const EdgeInsets.symmetric(horizontal: 20, vertical: 10));
    });

    testWidgets('fieldPadding from the theme is applied to a field', (tester) async {
      const padding = EdgeInsets.symmetric(horizontal: 8);

      await tester.pumpWidget(
        buildSubject(theme: const FormThemeData(fieldPadding: padding)),
      );

      expect(fieldPaddingOf(tester).padding, padding);
    });

    testWidgets('changing the theme data rebuilds dependent fields', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          theme: const FormThemeData(fieldPadding: EdgeInsets.symmetric(horizontal: 8)),
        ),
      );
      await tester.pumpWidget(
        buildSubject(
          theme: const FormThemeData(fieldPadding: EdgeInsets.symmetric(horizontal: 24)),
        ),
      );

      expect(fieldPaddingOf(tester).padding, const EdgeInsets.symmetric(horizontal: 24));
    });
  });

  group('FormThemeData', () {
    test('copyWith overrides only the given properties', () {
      const original = FormThemeData(
        fieldPadding: EdgeInsets.all(4),
        errorsPadding: EdgeInsets.all(6),
      );

      expect(original.copyWith().fieldPadding, const EdgeInsets.all(4));
      expect(original.copyWith().errorsPadding, const EdgeInsets.all(6));
      expect(
        original.copyWith(fieldPadding: EdgeInsets.zero).fieldPadding,
        EdgeInsets.zero,
      );
      expect(original.copyWith(fieldPadding: EdgeInsets.zero).errorsPadding, const EdgeInsets.all(6));
      expect(original.copyWith(errorsPadding: EdgeInsets.zero).errorsPadding, EdgeInsets.zero);
      expect(original.copyWith(errorsPadding: EdgeInsets.zero).fieldPadding, const EdgeInsets.all(4));
    });

    test('equality is value-based', () {
      expect(
        const FormThemeData(fieldPadding: EdgeInsets.all(4)),
        const FormThemeData(fieldPadding: EdgeInsets.all(4)),
      );
      expect(
        const FormThemeData(fieldPadding: EdgeInsets.all(4)),
        isNot(const FormThemeData(fieldPadding: EdgeInsets.all(8))),
      );
      expect(
        const FormThemeData(errorsPadding: EdgeInsets.all(6)),
        isNot(const FormThemeData(errorsPadding: EdgeInsets.all(10))),
      );
    });
  });
}

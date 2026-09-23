// The framed EditorGroup must always keep a visible frame: default outline
// without any theming, the app's inputDecorationTheme border when configured,
// FormThemeData.groupBorder above both.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_foundation/form_foundation.dart';

void main() {
  Widget wrap(Widget child, {ThemeData? theme, FormThemeData? formTheme}) {
    Widget body = Scaffold(body: child);
    if (formTheme != null) body = FormTheme(data: formTheme, child: body);
    return MaterialApp(theme: theme, home: body);
  }

  InputBorder? effectiveBorder(WidgetTester tester) => tester.widget<InputDecorator>(find.byType(InputDecorator)).decoration.border;

  group('EditorGroup frame border', () {
    testWidgets('falls back to OutlineInputBorder without any theming', (tester) async {
      await tester.pumpWidget(wrap(const EditorGroup(title: 'Group', content: Text('row'))));

      expect(effectiveBorder(tester), isA<OutlineInputBorder>());
    });

    testWidgets('inherits the border of the app inputDecorationTheme', (tester) async {
      const themed = UnderlineInputBorder(borderSide: BorderSide(color: Colors.red));
      await tester.pumpWidget(
        wrap(
          const EditorGroup(title: 'Group', content: Text('row')),
          theme: ThemeData(inputDecorationTheme: const InputDecorationTheme(border: themed)),
        ),
      );

      expect(effectiveBorder(tester), themed);
    });

    testWidgets('indents the floating label while the content stays flush', (tester) async {
      await tester.pumpWidget(wrap(const EditorGroup(title: 'Group', content: Text('row'))));

      // The label is drawn by its own decorator with a start contentPadding,
      // so it sits to the right of the unpadded content.
      final labelX = tester.getTopLeft(find.text('Group')).dx;
      final contentX = tester.getTopLeft(find.text('row')).dx;
      expect(labelX, greaterThan(contentX));
    });

    testWidgets('the label indent follows the horizontal contentPadding of the app theme', (tester) async {
      await tester.pumpWidget(
        wrap(
          const EditorGroup(title: 'Group', content: Text('row')),
          theme: ThemeData(
            inputDecorationTheme: const InputDecorationTheme(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
          ),
        ),
      );

      final decorator = tester.widget<InputDecorator>(find.byType(InputDecorator));
      expect(decorator.decoration.contentPadding, const EdgeInsetsDirectional.only(start: 10));
    });

    testWidgets('FormThemeData.groupBorder wins over the app theme', (tester) async {
      const group = OutlineInputBorder(borderSide: BorderSide(color: Colors.green, width: 3));
      await tester.pumpWidget(
        wrap(
          const EditorGroup(title: 'Group', content: Text('row')),
          theme: ThemeData(inputDecorationTheme: const InputDecorationTheme(border: UnderlineInputBorder())),
          formTheme: const FormThemeData(groupBorder: group),
        ),
      );

      expect(effectiveBorder(tester), group);
    });
  });
}

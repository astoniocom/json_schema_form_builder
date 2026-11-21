import 'package:flutter_test/flutter_test.dart';
import 'package:form_foundation/form_foundation.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Widget buildSubject({
    Iterable<String> errors = const [],
    FormThemeData? theme,
  }) {
    Widget child = Scaffold(body: ErrorsPanel(errors: errors));
    if (theme != null) {
      child = FormTheme(data: theme, child: child);
    }
    return MaterialApp(home: child);
  }

  Container innerContainer(WidgetTester tester) {
    return tester.widget<Container>(
      find.descendant(of: find.byType(ErrorsPanel), matching: find.byType(Container)),
    );
  }

  group('ErrorsPanel', () {
    testWidgets('renders nothing when there are no errors', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(
        find.descendant(of: find.byType(ErrorsPanel), matching: find.byType(Container)),
        findsNothing,
      );
      expect(find.byType(SelectableText), findsNothing);
    });

    testWidgets('shows every error as selectable text aligned to the start', (tester) async {
      await tester.pumpWidget(buildSubject(errors: ['first error', 'second error']));

      expect(find.text('first error'), findsOneWidget);
      expect(find.text('second error'), findsOneWidget);
      expect(find.byType(SelectableText), findsNWidgets(2));

      final column = tester.widget<Column>(
        find.descendant(of: find.byType(ErrorsPanel), matching: find.byType(Column)),
      );
      expect(column.crossAxisAlignment, CrossAxisAlignment.start);
    });

    testWidgets('uses the errorContainer/onErrorContainer color pair', (tester) async {
      await tester.pumpWidget(buildSubject(errors: ['error']));

      final context = tester.element(find.byType(ErrorsPanel));
      final colorScheme = Theme.of(context).colorScheme;

      final decoration = innerContainer(tester).decoration! as BoxDecoration;
      expect(decoration.color, colorScheme.errorContainer);
      expect(decoration.borderRadius, const BorderRadius.all(Radius.circular(4)));

      final text = tester.widget<SelectableText>(find.byType(SelectableText));
      expect(text.style?.color, colorScheme.onErrorContainer);
    });

    testWidgets('applies fieldPadding and errorsPadding from the theme', (tester) async {
      const theme = FormThemeData(
        fieldPadding: EdgeInsets.symmetric(horizontal: 16),
        errorsPadding: EdgeInsets.all(6),
      );

      await tester.pumpWidget(buildSubject(errors: ['error'], theme: theme));

      final outerPadding = tester.widget<Padding>(
        find.descendant(of: find.byType(ErrorsPanel), matching: find.byType(Padding)).first,
      );
      expect(outerPadding.padding, const EdgeInsets.symmetric(horizontal: 16));
      expect(innerContainer(tester).padding, const EdgeInsets.all(6));
    });

    testWidgets('marks the block as a live region for assistive technologies', (tester) async {
      await tester.pumpWidget(buildSubject(errors: ['error']));

      final semantics = find.descendant(
        of: find.byType(ErrorsPanel),
        matching: find.byWidgetPredicate((w) => w is Semantics && (w.properties.liveRegion ?? false)),
      );
      expect(semantics, findsOneWidget);
    });
  });
}

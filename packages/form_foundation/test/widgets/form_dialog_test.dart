import 'package:flutter_test/flutter_test.dart';
import 'package:form_foundation/form_foundation.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Widget buildSubject({VoidCallback? onClose}) {
    return MaterialApp(
      home: FormTheme(
        data: const FormThemeData(
          fieldPadding: EdgeInsets.fromLTRB(10, 4, 12, 6),
        ),
        child: Scaffold(
          body: FormDialog(
            title: const Text('Dialog title'),
            onClose: onClose,
            content: const SizedBox(width: 100, height: 50),
            actions: const [TextButton(onPressed: null, child: Text('OK'))],
          ),
        ),
      ),
    );
  }

  testWidgets('1. Title and actions paddings are derived from fieldPadding', (tester) async {
    await tester.pumpWidget(buildSubject());

    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    expect(dialog.titlePadding, const EdgeInsets.only(left: 10, right: 12, top: 24, bottom: 24 - 4.0));
    expect(dialog.actionsPadding, const EdgeInsets.only(left: 10, right: 12, top: 24, bottom: 24 - 6.0));
    expect(dialog.contentPadding, EdgeInsets.zero);
  });

  testWidgets('2. A close button appears only when onClose is set', (tester) async {
    await tester.pumpWidget(buildSubject());
    expect(find.byType(CloseButton), findsNothing);

    var closed = false;
    await tester.pumpWidget(buildSubject(onClose: () => closed = true));
    expect(find.byType(CloseButton), findsOneWidget);

    await tester.tap(find.byType(CloseButton));
    expect(closed, isTrue);
  });
}
